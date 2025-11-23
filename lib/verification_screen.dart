import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  Future<void> _updateStatus(
    BuildContext context,
    String uid,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${status == 'approved' ? 'approved' : 'rejected'}.',
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                title,
                style: const TextStyle(fontFamily: 'NexaBold'),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          SizedBox(height: 12),
                          Text('Failed to load image'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backfillMissingStatus(BuildContext context) async {
    // Fetch users without a status field (isNull query). Requires Firestore supporting isNull.
    try {
      final missingSnap = await FirebaseFirestore.instance
          .collection('Users')
          .where('status', isNull: true)
          .get();
      for (final doc in missingSnap.docs) {
        await doc.reference.set({'status': 'pending'}, SetOptions(merge: true));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backfilled ${missingSnap.docs.length} user(s).'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backfill failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pending Accounts',
          style: TextStyle(fontFamily: 'NexaBold'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading pending accounts:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'NexaRegular'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _backfillMissingStatus(context),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Backfill Missing Status'),
                    ),
                  ],
                ),
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No pending accounts found.',
                      style: TextStyle(fontFamily: 'NexaRegular'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _backfillMissingStatus(context),
                      icon: const Icon(Icons.build),
                      label: const Text('Backfill Missing Status'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (c, i) {
              final d = docs[i].data();
              final uid = d['uid'] ?? docs[i].id;
              final email = d['email'] ?? 'unknown';
              final role = d['role'] ?? 'n/a';
              final studentId = d['studentId'];
              final teacherId = d['teacherId'];
              final fullName = d['fullName'];
              final address = d['address'];
              final profileUrl = d['profilePictureUrl'];
              final idUrl = d['idScreenshotUrl'];

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Profile picture
                          if (profileUrl != null)
                            GestureDetector(
                              onTap: () => _showImageDialog(
                                context,
                                profileUrl,
                                'Profile Picture',
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundImage: NetworkImage(profileUrl),
                                backgroundColor: Colors.grey[200],
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[200],
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fullName != null)
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontFamily: 'NexaBold',
                                      fontSize: 16,
                                    ),
                                  ),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontFamily: 'NexaRegular',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Role: $role',
                        style: const TextStyle(fontFamily: 'NexaRegular'),
                      ),
                      if (studentId != null)
                        Text(
                          'Student ID: $studentId',
                          style: const TextStyle(fontFamily: 'NexaRegular'),
                        ),
                      if (teacherId != null)
                        Text(
                          'Teacher ID: $teacherId',
                          style: const TextStyle(fontFamily: 'NexaRegular'),
                        ),
                      if (address != null)
                        Text(
                          'Address: $address',
                          style: const TextStyle(
                            fontFamily: 'NexaRegular',
                            fontSize: 12,
                          ),
                        ),
                      // ID Screenshot
                      if (idUrl != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'ID Screenshot:',
                          style: TextStyle(
                            fontFamily: 'NexaBold',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () =>
                              _showImageDialog(context, idUrl, 'ID Screenshot'),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                idUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Failed to load',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () =>
                                _updateStatus(context, uid, 'approved'),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _updateStatus(context, uid, 'rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: docs.length,
          );
        },
      ),
    );
  }
}
