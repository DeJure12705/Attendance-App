import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendanceapp/services/location_service.dart';

// Token classification moved to top-level (enums cannot be inside classes)
enum _ScanType { checkIn, checkOut, dynamicToken, event, unknown }

// Student attendance screen with QR flows and geofence validation.
// Shows live date/time, check-in/out status, address, and map markers.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  double screenHeight = 0;
  double screenWidth = 0;
  final Color primary = const Color.fromARGB(252, 47, 145, 42);
  // Header name derived from `User.studentId` or SharedPreferences.
  String? _username;
  String checkIn = "--/--";
  String checkOut = "--/--";
  String location = " ";
  double? checkInLat;
  double? checkInLng;
  double? checkOutLat;
  double? checkOutLng;
  // FlutterMap does not need a controller for simple markers.

  // Classify scanned token to enforce correct sequence
  // Interpret a scanned token and decide the expected action.
  // Supports CHECKIN:, CHECKOUT:, DYN:, EVENT: prefixes; defaults to unknown.
  _ScanType _classifyToken(String token) {
    final t = token.trim().toUpperCase();
    if (t.startsWith('CHECKIN:')) return _ScanType.checkIn;
    if (t.startsWith('CHECKOUT:')) return _ScanType.checkOut;
    if (t.startsWith('DYN:')) return _ScanType.dynamicToken;
    if (t.startsWith('EVENT:')) return _ScanType.event;
    return _ScanType.unknown;
  }

  // Extract eventId from tokens like EVENT:<id> (or return null).
  String? _extractEventId(String token) {
    final parts = token.split(':');
    if (parts.length >= 2) {
      return parts[1];
    }
    return null;
  }

  // Validate current coordinates against an event geofence.
  // Returns null if valid; otherwise a user-friendly error string.
  Future<String?> _validateLocationForEvent(String eventId) async {
    if (eventId == 'NONE') return null; // no validation
    final eventSnap = await FirebaseFirestore.instance
        .collection('Events')
        .doc(eventId)
        .get();
    if (!eventSnap.exists) return 'Event not found';
    final data = eventSnap.data();
    if (data == null) return 'Event data missing';
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final eventLat = toDouble(data['locLat']);
    final eventLng = toDouble(data['locLng']);
    final radius = toDouble(data['locRadius']);
    if (eventLat == null || eventLng == null || radius == null) {
      // No location configured for this event; skip validation
      return null;
    }

    // Get current location at check-in time
    final locService = LocationService();
    final initialized = await locService.initialize();
    if (!initialized) return 'Unable to access location services';
    final userLat = await locService.getLatitude();
    final userLng = await locService.getLongitude();
    if (userLat == null || userLng == null) {
      return 'Unable to get your location';
    }

    // Update User static vars for consistency
    User.lat = userLat;
    User.long = userLng;

    // Ensure all values are doubles and compute distance in meters
    final distance = Geolocator.distanceBetween(
      userLat,
      userLng,
      eventLat,
      eventLng,
    );

    // Allow check-in when distance is <= radius (inclusive)
    if (distance <= radius) return null;

    return 'Check-in failed: You are not within the required location radius.';
  }

  @override
  void initState() {
    super.initState();
    // Initialize header, load today's record, then resolve address.
    _loadUsername();
    _getRecord();
    _waitForCoordinates();
  }

  // Reverse-geocode `User.lat/long` into a readable address.
  void _getLocation() async {
    if (User.lat == 0.0 || User.long == 0.0) return;
    try {
      final placemarks = await placemarkFromCoordinates(User.lat, User.long);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          location = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.postalCode,
            p.country,
          ].whereType<String>().where((e) => e.trim().isNotEmpty).join(', ');
        });
      }
    } catch (_) {}
  }

  // Poll for coordinates to be set; when present, fetch address.
  // After several attempts, fall back to "Location unavailable".
  void _waitForCoordinates() {
    if (User.lat != 0.0 && User.long != 0.0) {
      _getLocation();
      return;
    }
    int attempts = 0;
    const maxAttempts = 15;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      attempts++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (User.lat != 0.0 && User.long != 0.0) {
        timer.cancel();
        _getLocation();
      } else if (attempts >= maxAttempts) {
        timer.cancel();
        if (location.trim().isEmpty) {
          setState(() => location = 'Location unavailable');
        }
      }
    });
  }

  // Hydrate `_username` from memory or SharedPreferences.
  Future<void> _loadUsername() async {
    if (User.studentId.trim().isNotEmpty) {
      setState(() => _username = User.studentId.trim());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('studentId') ?? '';
    setState(() {
      _username = id;
      User.studentId = id;
    });
  }

  // Load today's attendance record from Firestore and populate UI fields.
  Future<void> _getRecord() async {
    final dateId = DateFormat('dd MMMM yyyy').format(DateTime.now());
    try {
      final studentQuery = await FirebaseFirestore.instance
          .collection('Student')
          .where('id', isEqualTo: User.studentId.trim())
          .limit(1)
          .get();
      if (studentQuery.docs.isEmpty) {
        setState(() {
          checkIn = '--/--';
          checkOut = '--/--';
        });
        return;
      }
      final studentDocId = studentQuery.docs.first.id;
      final recordRef = FirebaseFirestore.instance
          .collection('Student')
          .doc(studentDocId)
          .collection('Record')
          .doc(dateId);
      final recordSnap = await recordRef.get();
      if (!recordSnap.exists) {
        setState(() {
          checkIn = '--/--';
          checkOut = '--/--';
          checkInLat = null;
          checkInLng = null;
          checkOutLat = null;
          checkOutLng = null;
        });
        return;
      }
      final data = recordSnap.data() as Map<String, dynamic>;
      setState(() {
        checkIn = (data['checkIn'] ?? '--/--').toString();
        checkOut = (data['checkOut'] ?? '--/--').toString();
        checkInLat = (data['checkInLat'] is num)
            ? (data['checkInLat'] as num).toDouble()
            : null;
        checkInLng = (data['checkInLng'] is num)
            ? (data['checkInLng'] as num).toDouble()
            : null;
        checkOutLat = (data['checkOutLat'] is num)
            ? (data['checkOutLat'] as num).toDouble()
            : null;
        checkOutLng = (data['checkOutLng'] is num)
            ? (data['checkOutLng'] as num).toDouble()
            : null;
      });
      _refreshMapSymbols();
    } catch (_) {
      setState(() {
        checkIn = '--/--';
        checkOut = '--/--';
        checkInLat = null;
        checkInLng = null;
        checkOutLat = null;
        checkOutLng = null;
      });
    }
  }

  // Request permissions and capture a high-accuracy position.
  Future<Position?> _capturePrecisePosition() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          return null;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      return position;
    } catch (_) {
      return null;
    }
  }

  void _refreshMapSymbols() {
    // No-op retained for compatibility; FlutterMap rebuild handles markers.
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'Attendance',
          style: TextStyle(fontFamily: 'NexaBold'),
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {},
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: welcome + live date/time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome',
                        style: TextStyle(
                          color: Colors.black54,
                          fontFamily: 'NexaRegular',
                          fontSize: screenWidth / 25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _username != null && _username!.isNotEmpty
                            ? 'Student ${_username!}'
                            : 'Student',
                        style: TextStyle(
                          fontFamily: 'NexaBold',
                          fontSize: screenWidth / 18,
                        ),
                      ),
                    ],
                  ),
                  // Date & Time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(DateTime.now()),
                        style: TextStyle(
                          fontFamily: 'NexaRegular',
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Live clock updated every second
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(seconds: 1)),
                        builder: (context, snapshot) {
                          return Text(
                            DateFormat('hh:mm:ss a').format(DateTime.now()),
                            style: TextStyle(
                              fontFamily: 'NexaRegular',
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Status card: shows current check-in and check-out times
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      // Check-in
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: checkIn == '--/--'
                                    ? Colors.orange[50]
                                    : Colors.green[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.login,
                                color: checkIn == '--/--'
                                    ? Colors.orange
                                    : Colors.green,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Check In',
                              style: TextStyle(
                                fontFamily: 'NexaRegular',
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              checkIn,
                              style: TextStyle(
                                fontFamily: 'NexaBold',
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider
                      Container(height: 64, width: 1, color: Colors.grey[200]),
                      // Check-out
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: checkOut == '--/--'
                                    ? Colors.blue[50]
                                    : Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.logout,
                                color: checkOut == '--/--'
                                    ? Colors.blue
                                    : Colors.grey[700],
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Check Out',
                              style: TextStyle(
                                fontFamily: 'NexaRegular',
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              checkOut,
                              style: TextStyle(
                                fontFamily: 'NexaBold',
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Location chip: reverse-geocoded address for current coordinates
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.black45,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location.trim().isNotEmpty
                          ? location
                          : 'Fetching location...',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontFamily: 'NexaRegular',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              // Map: show markers for check-in/out coordinates when available
              if (checkInLat != null || checkOutLat != null)
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: latlng.LatLng(
                          (checkOutLat ?? checkInLat) ?? 0.0,
                          (checkOutLng ?? checkInLng) ?? 0.0,
                        ),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          enableMultiFingerGestureRace: true,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.attendanceapp',
                        ),
                        MarkerLayer(
                          markers: [
                            if (checkInLat != null && checkInLng != null)
                              Marker(
                                width: 40,
                                height: 40,
                                point: latlng.LatLng(checkInLat!, checkInLng!),
                                child: _buildMarker('IN', Colors.green),
                              ),
                            if (checkOutLat != null && checkOutLng != null)
                              Marker(
                                width: 40,
                                height: 40,
                                point: latlng.LatLng(
                                  checkOutLat!,
                                  checkOutLng!,
                                ),
                                child: _buildMarker('OUT', Colors.blue),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 26),

              // Scan CTA: triggers QR scan and handles sequential CHECKIN then CHECKOUT,
              // including event geofence validation and Firestore persistence.
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 22),
                    label: Text(
                      checkIn == '--/--'
                          ? 'Scan to Check In'
                          : (checkOut == '--/--'
                                ? 'Scan to Check Out'
                                : 'Scans Completed'),
                      style: const TextStyle(
                        fontFamily: 'NexaBold',
                        fontSize: 16,
                      ),
                    ),
                    onPressed: checkOut == '--/--'
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final code = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _QrScanScreen(primary: primary),
                              ),
                            );
                            if (!mounted) return;
                            if (code == null) return;
                            // Classify token intent and capture precise coordinates.
                            final scanType = _classifyToken(code);
                            final position = await _capturePrecisePosition();
                            if (!mounted) return;
                            double? lat = position?.latitude;
                            double? lng = position?.longitude;
                            if (position != null) {
                              try {
                                final placemarks =
                                    await placemarkFromCoordinates(
                                      position.latitude,
                                      position.longitude,
                                    );
                                if (!mounted) return;
                                if (placemarks.isNotEmpty) {
                                  final p = placemarks.first;
                                  location =
                                      [
                                            p.street,
                                            p.subLocality,
                                            p.locality,
                                            p.administrativeArea,
                                            p.postalCode,
                                            p.country,
                                          ]
                                          .whereType<String>()
                                          .where((e) => e.trim().isNotEmpty)
                                          .join(', ');
                                }
                              } catch (_) {}
                            }
                            final now = DateTime.now();
                            final dateId = DateFormat(
                              'dd MMMM yyyy',
                            ).format(now);
                            final timeStr = DateFormat('hh:mm').format(now);
                            try {
                              final studentQuery = await FirebaseFirestore
                                  .instance
                                  .collection('Student')
                                  .where('id', isEqualTo: User.studentId.trim())
                                  .limit(1)
                                  .get();
                              if (!mounted) return;
                              if (studentQuery.docs.isEmpty) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Student record not found'),
                                  ),
                                );
                                return;
                              }
                              final studentDocId = studentQuery.docs.first.id;
                              final recordRef = FirebaseFirestore.instance
                                  .collection('Student')
                                  .doc(studentDocId)
                                  .collection('Record')
                                  .doc(dateId);
                              final recordSnap = await recordRef.get();
                              if (!mounted) return;
                              final existing = recordSnap.data();

                              // Guard: wrong sequence or duplicate scans
                              if (checkIn == '--/--') {
                                // Expect a CHECKIN token for first scan
                                if (scanType != _ScanType.checkIn) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please scan a CHECK-IN QR first',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                // Validate location for event
                                final eventId = _extractEventId(code) ?? 'NONE';
                                final validationError =
                                    await _validateLocationForEvent(eventId);
                                if (validationError != null) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(validationError)),
                                  );
                                  return;
                                }
                                await recordRef.set({
                                  'date': Timestamp.now(),
                                  'checkIn': timeStr,
                                  'checkOut': '--/--',
                                  'location': location,
                                  'qrCode': code,
                                  if (lat != null) 'checkInLat': lat,
                                  if (lng != null) 'checkInLng': lng,
                                }, SetOptions(merge: true));
                                if (!mounted) return;
                                setState(() {
                                  checkIn = timeStr;
                                  checkInLat = lat;
                                  checkInLng = lng;
                                });
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Checked in via QR'),
                                  ),
                                );
                              } else if (checkOut == '--/--') {
                                // Already checked in; require CHECKOUT token
                                final storedCheckInCode = existing == null
                                    ? null
                                    : existing['qrCode'];
                                if (scanType == _ScanType.checkIn &&
                                    storedCheckInCode == code) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Already checked in with this QR',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (scanType != _ScanType.checkOut) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Scan a CHECK-OUT QR to check out',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                // Validate location for event
                                final eventId = _extractEventId(code) ?? 'NONE';
                                final validationError =
                                    await _validateLocationForEvent(eventId);
                                if (validationError != null) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(validationError)),
                                  );
                                  return;
                                }
                                if (!recordSnap.exists) {
                                  await recordRef.set({
                                    'checkIn': checkIn,
                                    'checkOut': timeStr,
                                    'qrCodeOut': code,
                                    if (lat != null) 'checkOutLat': lat,
                                    if (lng != null) 'checkOutLng': lng,
                                  });
                                } else {
                                  final storedOutCode = existing?['qrCodeOut'];
                                  if (storedOutCode == code) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Already checked out with this QR',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  await recordRef.update({
                                    'checkOut': timeStr,
                                    'qrCodeOut': code,
                                    if (lat != null) 'checkOutLat': lat,
                                    if (lng != null) 'checkOutLng': lng,
                                  });
                                }
                                if (!mounted) return;
                                setState(() {
                                  checkOut = timeStr;
                                  checkOutLat = lat;
                                  checkOutLng = lng;
                                });
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Checked out via QR'),
                                  ),
                                );
                              } else {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Already checked out today'),
                                  ),
                                );
                              }
                              if (!mounted) return;
                              // Refresh UI to reflect latest record and markers
                              _getRecord();
                              _refreshMapSymbols();
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('QR attendance failed'),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'NexaBold',
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// QR scanner page implemented with mobile_scanner; returns scanned value.
class _QrScanScreen extends StatefulWidget {
  final Color primary;
  const _QrScanScreen({required this.primary});

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.primary,
        title: const Text(
          'Scan Attendance QR',
          style: TextStyle(fontFamily: 'NexaBold'),
        ),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw == null || raw.trim().isEmpty) return;
              // Prevent multiple pops; return the trimmed QR payload.
              _done = true;
              Navigator.pop(context, raw.trim());
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: const Text(
                'Point camera at the provided QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'NexaRegular',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
