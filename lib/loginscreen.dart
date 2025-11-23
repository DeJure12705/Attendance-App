import 'package:flutter/material.dart';

/// Deprecated legacy StudentID login screen.
/// Use `RoleLoginScreen` for authentication (email/password + role).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Legacy login removed. Use the new role-based login screen.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
