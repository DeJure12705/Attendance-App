import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/location_picker_screen.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Events')),
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
            return const Center(child: Text('No events found.'));
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
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editEvent(event),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteEvent(event.id),
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

  Future<void> _editEvent(DocumentSnapshot event) async {
    final data = event.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    double lat = (data['locLat'] as num?)?.toDouble() ?? 0.0;
    double lng = (data['locLng'] as num?)?.toDouble() ?? 0.0;
    double radius = (data['locRadius'] as num?)?.toDouble() ?? 100.0;

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
}
