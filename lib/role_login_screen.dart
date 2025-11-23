import 'package:attendanceapp/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/complete_credentials_screen.dart';
import 'package:attendanceapp/pending_verification_screen.dart';
import 'package:attendanceapp/homescreen.dart';
import 'package:attendanceapp/teacher_home.dart';
import 'package:attendanceapp/admin_home.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class RoleLoginScreen extends StatefulWidget {
  const RoleLoginScreen({super.key});
  @override
  State<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends State<RoleLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _mode = 'login'; // or 'register'
  String _role = 'student'; // default role
  bool _loading = false;
  bool _showPassword = false;
  String? _error;
  bool _socialLoading = false;

  final AuthService _auth = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final studentId = _role == 'student'
        ? _studentIdController.text.trim()
        : null;
    String? err;
    if (_mode == 'login') {
      err = await _auth.signIn(email: email, password: password);
    } else {
      err = await _auth.register(
        email: email,
        password: password,
        role: _role,
        studentId: studentId,
      );
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _error = err;
      });
      if (err == null) {
        // Proactively navigate after success to leave this screen.
        final current = fb.FirebaseAuth.instance.currentUser;
        if (current != null) {
          await Future.delayed(const Duration(milliseconds: 150));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoadingScreen()),
            );
          }
          Widget? target;
          if (User.status == 'incomplete') {
            // Use the selected role on this form to choose the correct screen
            if (_role == 'student') {
              target = const CompleteCredentialsScreen(forcedRole: 'student');
            } else if (_role == 'teacher') {
              target = const CompleteCredentialsScreen(forcedRole: 'teacher');
            } else {
              target = const CompleteCredentialsScreen();
            }
          } else if (User.status == 'pending') {
            target = const PendingVerificationScreen();
          } else {
            switch (User.role) {
              case 'student':
                target = const Homescreen();
                break;
              case 'teacher':
                target = const TeacherHome();
                break;
              case 'admin':
                target = const AdminHome();
                break;
              default:
                target = null;
            }
          }
          if (target != null && mounted) {
            Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute(builder: (_) => target!));
          }
        }
      }
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _socialLoading = true;
      _error = null;
    });
    final desiredRole = _role; // user-selected role before Google auth
    final studentId = desiredRole == 'student'
        ? _studentIdController.text.trim()
        : null;
    final err = await _auth.signInWithGoogle(
      desiredRole: desiredRole,
      studentId: studentId,
    );
    if (!mounted) return;
    setState(() {
      _socialLoading = false;
      _error = err;
    });
    if (err == null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoadingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromARGB(252, 47, 145, 42);
    final accent = primary.withOpacity(.85);

    InputDecoration baseDecoration(String label, {IconData? icon}) =>
        InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          floatingLabelStyle: const TextStyle(fontFamily: 'NexaBold'),
          labelStyle: const TextStyle(fontFamily: 'NexaRegular'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withOpacity(.6), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _mode == 'login' ? 'Welcome Back' : 'Create Account',
                          style: const TextStyle(
                            fontFamily: 'NexaBold',
                            fontSize: 28,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Attendance App',
                          style: TextStyle(
                            fontFamily: 'NexaRegular',
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ToggleButtons(
                          isSelected: [_mode == 'login', _mode == 'register'],
                          onPressed: (i) => setState(
                            () => _mode = i == 0 ? 'login' : 'register',
                          ),
                          borderRadius: BorderRadius.circular(12),
                          selectedColor: Colors.white,
                          color: accent,
                          fillColor: accent,
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              child: Text(
                                'Login',
                                style: TextStyle(fontFamily: 'NexaBold'),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              child: Text(
                                'Register',
                                style: TextStyle(fontFamily: 'NexaBold'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'student',
                              label: Text('Student'),
                            ),
                            ButtonSegment(
                              value: 'teacher',
                              label: Text('Teacher'),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: (s) =>
                              setState(() => _role = s.first),
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          decoration: baseDecoration(
                            'Email',
                            icon: Icons.email,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email required';
                            }
                            final reg = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!reg.hasMatch(v.trim())) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration:
                              baseDecoration(
                                'Password',
                                icon: Icons.lock,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                ),
                              ),
                          obscureText: !_showPassword,
                          validator: (v) {
                            if (v == null || v.length < 6) {
                              return 'Min 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (_role == 'student') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _studentIdController,
                            decoration: baseDecoration(
                              'Student ID',
                              icon: Icons.badge,
                            ),
                            validator: (v) {
                              if (_role == 'student' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Student ID required';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _error == null
                              ? const SizedBox(height: 0)
                              : Container(
                                  key: ValueKey(_error),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Dismiss',
                                        onPressed: () =>
                                            setState(() => _error = null),
                                        icon: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _mode == 'login' ? 'Login' : 'Register',
                                    style: const TextStyle(
                                      fontFamily: 'NexaBold',
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(
                            () =>
                                _mode = _mode == 'login' ? 'register' : 'login',
                          ),
                          child: Text(
                            _mode == 'login'
                                ? 'Need an account? Register'
                                : 'Have an account? Login',
                            style: const TextStyle(fontFamily: 'NexaRegular'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _socialLoading ? null : _googleLogin,
                                icon: const Icon(
                                  Icons.account_circle,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Continue with Google',
                                  style: TextStyle(fontFamily: 'NexaBold'),
                                ),
                              ),
                            ),

                            if (_socialLoading) ...[
                              const SizedBox(height: 12),
                              const Center(
                                child: SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Social sign-in creates an incomplete profile. You must choose a role (and Student ID if student) before approval.',
                              style: const TextStyle(
                                fontFamily: 'NexaRegular',
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Students must supply a valid Student ID to link attendance records.',
                              style: const TextStyle(
                                fontFamily: 'NexaRegular',
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
