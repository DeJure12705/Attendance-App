import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/location_picker_screen.dart';
import 'package:attendanceapp/services/location_service.dart';

enum QrKind { checkIn, checkOut, dynamicToken, eventSpecific }

class UnifiedEventScreen extends StatefulWidget {
  const UnifiedEventScreen({super.key});

  @override
  State<UnifiedEventScreen> createState() => _UnifiedEventScreenState();
}

class _UnifiedEventScreenState extends State<UnifiedEventScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  QrKind _kind = QrKind.checkIn;
  int _intervalSeconds = 30;
  String? _selectedEventId;
  StreamSubscription? _timerSub;
  String _currentToken = '';
  bool _publishing = false;
  final Random _rand = Random();

  @override
  void dispose() {
    _timerSub?.cancel();
    super.dispose();
  }

  Future<void> _createEvent() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Event'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Event name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      // Get current location for initial map position
      final locService = LocationService();
      final initialized = await locService.initialize();
      double lat = 0.0;
      double lng = 0.0;
      if (initialized) {
        lat = await locService.getLatitude() ?? 0.0;
        lng = await locService.getLongitude() ?? 0.0;
      }
      final docRef = await _db.collection('Events').add({
        'name': nameCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'creatorRole': User.role,
        'creatorUid': User.uid,
        'locLat': lat,
        'locLng': lng,
        'locRadius': 100.0, // default
      });
      setState(() => _selectedEventId = docRef.id);
    }
  }

  Future<void> _editEvent(DocumentSnapshot event) async {
    final data = event.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    double lat = (data['locLat'] as num?)?.toDouble() ?? 0.0;
    double lng = (data['locLng'] as num?)?.toDouble() ?? 0.0;
    double radius = (data['locRadius'] as num?)?.toDouble() ?? 100.0;

    // If no location set, get current location
    if (lat == 0.0 && lng == 0.0) {
      final locService = LocationService();
      final initialized = await locService.initialize();
      if (initialized) {
        lat = await locService.getLatitude() ?? 0.0;
        lng = await locService.getLongitude() ?? 0.0;
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Event Name'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                ),
                Text('Radius: ${radius.toStringAsFixed(0)}m'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await Navigator.of(ctx)
                        .push<Map<String, dynamic>>(
                          MaterialPageRoute(
                            builder: (_) => LocationPickerScreen(
                              initialLat: lat,
                              initialLng: lng,
                              initialRadius: radius,
                            ),
                          ),
                        );
                    if (picked != null) {
                      setState(() {
                        lat = picked['lat'];
                        lng = picked['lng'];
                        radius = picked['radius'];
                      });
                    }
                  },
                  child: const Text('Edit Location & Radius'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      await _db.collection('Events').doc(event.id).update({
        'name': nameCtrl.text.trim(),
        'locLat': lat,
        'locLng': lng,
        'locRadius': radius,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.collection('Events').doc(eventId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
      }
    }
  }

  String _buildStaticToken() {
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    switch (_kind) {
      case QrKind.checkIn:
        return 'CHECKIN:${_selectedEventId ?? 'NONE'}:$dateStr';
      case QrKind.checkOut:
        return 'CHECKOUT:${_selectedEventId ?? 'NONE'}:$dateStr';
      case QrKind.eventSpecific:
        return 'EVENT:${_selectedEventId ?? 'NONE'}';
      case QrKind.dynamicToken:
        return '';
    }
  }

  String _generateDynamicToken() {
    final nonce = _rand.nextInt(1 << 32).toRadixString(16);
    final now = DateTime.now();
    final dateStr = now.toIso8601String().substring(0, 10);
    return 'DYN:${_selectedEventId ?? 'NONE'}:$dateStr:${now.millisecondsSinceEpoch}:$nonce';
  }

  Future<void> _publishToken(
    String token, {
    required QrKind kind,
    int? validitySeconds,
  }) async {
    if (_selectedEventId == null) return;
    setState(() => _publishing = true);
    final data = {
      'token': token,
      'kind': kind.name,
      'createdAt': FieldValue.serverTimestamp(),
      if (validitySeconds != null) 'validFor': validitySeconds,
      'eventId': _selectedEventId,
      'issuerUid': User.uid,
    };
    await _db
        .collection('Events')
        .doc(_selectedEventId)
        .collection('activeTokens')
        .doc(token)
        .set(data);
    setState(() => _publishing = false);
  }

  void _generateQR(String eventId) {
    setState(() => _selectedEventId = eventId);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Generate QR Code'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<QrKind>(
                  value: _kind,
                  items: QrKind.values
                      .map(
                        (k) => DropdownMenuItem(value: k, child: Text(k.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _kind = v!),
                ),
                if (_kind == QrKind.dynamicToken)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Interval (seconds)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _intervalSeconds = int.tryParse(v) ?? 30,
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _publishing
                      ? null
                      : () async {
                          if (_kind == QrKind.dynamicToken) {
                            _timerSub?.cancel();
                            final first = _generateDynamicToken();
                            setState(() => _currentToken = first);
                            await _publishToken(
                              first,
                              kind: QrKind.dynamicToken,
                              validitySeconds: _intervalSeconds,
                            );
                            _timerSub =
                                Stream.periodic(
                                  Duration(seconds: _intervalSeconds),
                                ).listen((_) {
                                  final t = _generateDynamicToken();
                                  setState(() => _currentToken = t);
                                  _publishToken(
                                    t,
                                    kind: QrKind.dynamicToken,
                                    validitySeconds: _intervalSeconds,
                                  );
                                });
                          } else {
                            final token = _buildStaticToken();
                            setState(() => _currentToken = token);
                            await _publishToken(token, kind: _kind);
                          }
                        },
                  child: Text(
                    _kind == QrKind.dynamicToken
                        ? 'Start Dynamic QR'
                        : 'Generate QR',
                  ),
                ),
                if (_currentToken.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: QrImageView(data: _currentToken, size: 200),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _timerSub?.cancel();
                Navigator.pop(ctx);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ).then((_) => _timerSub?.cancel());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEvent,
        tooltip: 'Create Event',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('Events')
            .where('creatorUid', isEqualTo: User.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!.docs;
          if (events.isEmpty) {
            return const Center(
              child: Text('No events found. Create one to get started.'),
            );
          }
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final data = event.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unnamed Event';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final locLat = data['locLat'];
              final locLng = data['locLng'];
              final locRadius = data['locRadius'] ?? 100.0;
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(
                    'Created: ${createdAt != null ? createdAt.toString().substring(0, 16) : 'Unknown'}\n'
                    'Location: ${locLat != null && locLng != null ? '${locLat.toStringAsFixed(4)}, ${locLng.toStringAsFixed(4)}' : 'Not set'}\n'
                    'Radius: ${locRadius.toStringAsFixed(0)}m',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code),
                        onPressed: () => _generateQR(event.id),
                        tooltip: 'Generate QR',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editEvent(event),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteEvent(event.id),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
