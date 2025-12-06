import 'package:flutter/material.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/login_page.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/verification_screen.dart';
import 'package:attendanceapp/unified_event_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  String? _teacherName;
  bool _loadingName = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(User.uid)
          .get();

      if (userSnap.exists) {
        final data = userSnap.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _teacherName = data['fullName']?.toString();
            _loadingName = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loadingName = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingName = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teacher Dashboard',
          style: TextStyle(fontFamily: 'NexaBold'),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Manage Events',
            icon: const Icon(Icons.event),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UnifiedEventScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header with welcome and date/time
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
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loadingName ? 'Teacher' : (_teacherName ?? 'Teacher'),
                      style: const TextStyle(
                        fontFamily: 'NexaBold',
                        fontSize: 24,
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

            const SizedBox(height: 12),
            Text(
              'Email: ${User.email}',
              style: const TextStyle(fontFamily: 'NexaRegular'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VerificationScreen()),
                );
              },
              icon: const Icon(Icons.verified_user),
              label: const Text('Verify Accounts'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
