import 'package:attendanceapp/homescreen.dart';
import 'package:attendanceapp/admin_home.dart';
import 'package:attendanceapp/teacher_home.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/services/messaging_service.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/role_login_screen.dart';
import 'package:attendanceapp/pending_verification_screen.dart';
import 'package:attendanceapp/complete_credentials_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
// Removed unused SharedPreferences import and duplicate user import.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Activate App Check. Use Play Integrity for production; switch to debug during local dev if needed.
  // Use debug provider in debug/profile builds to bypass anti-abuse reCAPTCHA issues during setup.
  // Switch automatically to Play Integrity in release for production protection.
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
  );
  // Initialize FCM after Firebase & before runApp; actual token save occurs after login.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: KeyboardVisibilityProvider(child: AuthCheck()),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final fbUser = snapshot.data;
        if (fbUser == null) {
          return const RoleLoginScreen();
        }
        // Route incomplete status BEFORE checking for role (social users have no role yet).
        if (User.status == 'incomplete') {
          return const CompleteCredentialsScreen();
        }
        // Pending verification screen.
        if (User.status == 'pending') {
          // Initialize messaging service to capture token for notification.
          MessagingService().initialize();
          return const PendingVerificationScreen();
        }
        // Rare race: user doc loaded but role still empty (non-incomplete/pending)
        if (User.role.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Finalizing sign-in...',
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }
        switch (User.role) {
          case 'student':
            return const Homescreen();
          case 'teacher':
            return const TeacherHome();
          case 'admin':
            return const AdminHome();
          default:
            return const RoleLoginScreen();
        }
      },
    );
  }
}
