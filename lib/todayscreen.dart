import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  double screenHeight = 0;
  double screenWidth = 0;
  final Color primary = const Color.fromARGB(252, 47, 145, 42);
  String? _username;
  String checkIn = "--/--";
  String checkOut = "--/--";
  String location = " ";

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _getRecord();
    _waitForCoordinates();
  }

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
        });
        return;
      }
      final data = recordSnap.data() as Map<String, dynamic>;
      setState(() {
        checkIn = (data['checkIn'] ?? '--/--').toString();
        checkOut = (data['checkOut'] ?? '--/--').toString();
      });
    } catch (_) {
      setState(() {
        checkIn = '--/--';
        checkOut = '--/--';
      });
    }
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
              // Header
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

              // Status card
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

              // Location chip
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

              const SizedBox(height: 26),

              // Scan CTA
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
                            final code = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _QrScanScreen(primary: primary),
                              ),
                            );
                            if (code == null) return;
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
                              if (studentQuery.docs.isEmpty) return;
                              final studentDocId = studentQuery.docs.first.id;
                              final recordRef = FirebaseFirestore.instance
                                  .collection('Student')
                                  .doc(studentDocId)
                                  .collection('Record')
                                  .doc(dateId);
                              final recordSnap = await recordRef.get();
                              if (checkIn == '--/--') {
                                await recordRef.set({
                                  'date': Timestamp.now(),
                                  'checkIn': timeStr,
                                  'checkOut': '--/--',
                                  'location': location,
                                  'qrCode': code,
                                }, SetOptions(merge: true));
                                setState(() => checkIn = timeStr);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Checked in via QR'),
                                  ),
                                );
                              } else if (checkOut == '--/--') {
                                if (!recordSnap.exists) {
                                  await recordRef.set({
                                    'checkIn': checkIn,
                                    'checkOut': timeStr,
                                    'qrCodeOut': code,
                                  });
                                } else {
                                  await recordRef.update({
                                    'checkOut': timeStr,
                                    'qrCodeOut': code,
                                  });
                                }
                                setState(() => checkOut = timeStr);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Checked out via QR'),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Already checked out today'),
                                  ),
                                );
                              }
                              _getRecord();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
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
}

// QR scan screen widget
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
