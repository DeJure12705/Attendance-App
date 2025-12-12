import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:attendanceapp/model/user.dart';

class VerificationScreen extends StatelessWidget {
  // Add a flag to restrict the view to students only
  final bool onlyStudents;
  // Teacher's advisory section (for filtering and validation)
  final String? teacherAdvisory;
  // Current user's role (admin or teacher)
  final String? userRole;

  const VerificationScreen({
    super.key,
    this.onlyStudents = false, // Defaults to showing everyone (for Admin)
    this.teacherAdvisory,
    this.userRole,
  });

  Future<void> _updateStatus(
    BuildContext context,
    String uid,
    String status,
    Map<String, dynamic> userData,
  ) async {
    try {
      // Validation: Teachers can only approve/reject students in their advisory
      if (userRole == 'teacher') {
        final userAdvisory =
            userData['advisory']?.toString() ??
            userData['section']?.toString() ??
            userData['adviserTeacherAdvisory']?.toString();
        final userRoleFromDoc = userData['role']?.toString();

        // Teachers can only approve students
        if (userRoleFromDoc != 'student') {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Teachers can only approve/reject students.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Teachers can only approve students in their advisory
        if (teacherAdvisory == null ||
            teacherAdvisory!.isEmpty ||
            userAdvisory != teacherAdvisory) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You can only approve students in your advisory section (${teacherAdvisory ?? "None"}).',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      // If validation passes (or admin), proceed with status update
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': User.uid, // Track who approved/rejected
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
    // Construct Query
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('Users')
        .where('status', isEqualTo: 'pending');

    // IF TEACHER: Filter strictly for students (role filtering only in query)
    if (onlyStudents) {
      query = query.where('role', isEqualTo: 'student');
      // Advisory filtering will be done client-side to avoid index requirements
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userRole == 'teacher'
              ? 'Verify Students (${teacherAdvisory ?? "No Advisory"})'
              : 'Pending Accounts',
          style: const TextStyle(fontFamily: 'NexaBold', color: Colors.white),
        ),
        backgroundColor: const Color(0xFF28a745), // Success Green
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Center(
        // Responsive Constraint
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
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
              var docs = snapshot.data?.docs ?? [];

              // Client-side filtering for teachers by advisory
              if (userRole == 'teacher' &&
                  teacherAdvisory != null &&
                  teacherAdvisory!.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data();
                  final userAdvisory =
                      data['advisory']?.toString() ??
                      data['section']?.toString() ??
                      data['adviserTeacherAdvisory']?.toString();
                  return userAdvisory == teacherAdvisory;
                }).toList();
              }

              // Client-side sorting by createdAt (newest first)
              docs.sort((a, b) {
                final aCreatedAt = a.data()['createdAt'] as Timestamp?;
                final bCreatedAt = b.data()['createdAt'] as Timestamp?;

                // Handle null timestamps - put them at the end
                if (aCreatedAt == null && bCreatedAt == null) return 0;
                if (aCreatedAt == null) return 1;
                if (bCreatedAt == null) return -1;

                // Sort descending (newest first)
                return bCreatedAt.compareTo(aCreatedAt);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userRole == 'teacher'
                              ? 'No pending students found in your advisory (${teacherAdvisory ?? "None"}).'
                              : 'No pending accounts found.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'NexaRegular'),
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
                  final userAdvisory =
                      d['advisory']?.toString() ??
                      d['section']?.toString() ??
                      d['adviserTeacherAdvisory']?.toString();

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
                          if (userAdvisory != null)
                            Text(
                              'Advisory/Section: $userAdvisory',
                              style: const TextStyle(
                                fontFamily: 'NexaBold',
                                fontSize: 13,
                                color: Colors.blueAccent,
                              ),
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
                              onTap: () => _showImageDialog(
                                context,
                                idUrl,
                                'ID Screenshot',
                              ),
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
                                          if (loadingProgress == null) {
                                            return child;
                                          }
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
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // REJECT (Red)
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _updateStatus(context, uid, 'rejected', d),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // APPROVE (Green)
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _updateStatus(context, uid, 'approved', d),
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                ),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
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
        ),
      ),
    );
  }
}
