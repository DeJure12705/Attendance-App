import 'package:flutter/material.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/login_page.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/qr_generator_screen.dart';
import 'package:attendanceapp/verification_screen.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
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
            tooltip: 'QR Generator',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrGeneratorScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Verify Accounts',
            icon: const Icon(Icons.verified_user),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VerificationScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Admin',
              style: const TextStyle(fontFamily: 'NexaBold', fontSize: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'Email: ${User.email}',
              style: const TextStyle(fontFamily: 'NexaRegular'),
            ),
            const SizedBox(height: 24),
            // Admin actions placeholder; logout moved to AppBar.
            const SizedBox(height: 24),
            const Text(
              'TODO: Implement admin tools (manage users, reports).',
              style: TextStyle(fontFamily: 'NexaRegular'),
            ),
          ],
        ),
      ),
    );
  }
}
