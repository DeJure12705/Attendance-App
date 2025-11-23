import 'package:flutter/material.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/login_page.dart';
import 'package:attendanceapp/complete_credentials_screen.dart';
import 'package:attendanceapp/loading_screen.dart';
import 'package:attendanceapp/pending_verification_screen.dart';
import 'package:attendanceapp/homescreen.dart';
import 'package:attendanceapp/teacher_home.dart';
import 'package:attendanceapp/admin_home.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _role = 'student';
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;
  bool _socialLoading = false;

  final AuthService _auth = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final studentId = _role == 'student'
        ? _studentIdController.text.trim()
        : null;
    final err = await _auth.register(
      email: email,
      password: password,
      role: _role,
      studentId: studentId,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _error = err;
      });
      if (err != null && err.startsWith('Email already in use')) {
        _showEmailInUseDialog(email, password);
      } else if (err == null) {
        // Success: Fallback navigation to ensure we leave the register screen.
        // Auth stream should also handle this, but we navigate proactively.
        final current = fb.FirebaseAuth.instance.currentUser;
        if (current != null) {
          await Future.delayed(const Duration(milliseconds: 150));
          // Show loading screen while deciding target
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoadingScreen()),
            );
          }
          Widget? target;
          if (User.status == 'incomplete') {
            // Navigate to role-specific complete profile when role known
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

  void _showEmailInUseDialog(String email, String password) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Email Already Registered'),
          content: const Text(
            'This email already has an account. You can sign in or convert the existing account to teacher (pending approval).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Navigate to login page
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: const Text('Sign In'),
            ),
            if (_role == 'teacher')
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  // Attempt sign in then role change
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  final signErr = await _auth.signIn(
                    email: email,
                    password: password,
                  );
                  if (signErr != null) {
                    setState(() {
                      _loading = false;
                      _error = signErr;
                    });
                    return;
                  }
                  final roleErr = await _auth.requestRoleChange(
                    newRole: 'teacher',
                  );
                  if (mounted) {
                    setState(() {
                      _loading = false;
                      _error = roleErr;
                    });
                    if (roleErr == null) {
                      // Show pending status info
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Role change submitted. Await approval.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    }
                  }
                },
                child: const Text('Convert to Teacher'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _googleLogin() async {
    setState(() {
      _socialLoading = true;
      _error = null;
    });
    final desiredRole = _role; // from segmented selector
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
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromARGB(252, 47, 145, 42);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withOpacity(.6), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
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
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Create Account',
                            style: TextStyle(
                              fontFamily: 'NexaBold',
                              fontSize: 32,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join our attendance system',
                            style: TextStyle(
                              fontFamily: 'NexaRegular',
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          // Role Selector
                          const Text(
                            'I am a:',
                            style: TextStyle(
                              fontFamily: 'NexaBold',
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'student',
                                label: Text('Student'),
                                icon: Icon(Icons.school),
                              ),
                              ButtonSegment(
                                value: 'teacher',
                                label: Text('Teacher'),
                                icon: Icon(Icons.person),
                              ),
                            ],
                            selected: {_role},
                            onSelectionChanged: (s) =>
                                setState(() => _role = s.first),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (!v.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),
                          if (_role == 'student') ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _studentIdController,
                              decoration: InputDecoration(
                                labelText: 'Student ID',
                                prefixIcon: const Icon(Icons.badge),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                helperText: 'Required for student registration',
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
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              helperText: 'At least 6 characters',
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v.length < 6) return 'At least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_showConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _showConfirmPassword =
                                      !_showConfirmPassword,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v != _passwordController.text) {
                                return 'Passwords must match';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontFamily: 'NexaRegular',
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontFamily: 'NexaBold',
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontFamily: 'NexaRegular',
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _socialLoading ? null : _googleLogin,
                            icon: Image.asset(
                              'assets/pics/google.png',
                              height: 24,
                            ),
                            label: const Text('Continue with Google'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    fontFamily: 'NexaRegular',
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontFamily: 'NexaBold',
                                    color: primary,
                                    fontSize: 14,
                                  ),
                                ),
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
      ),
    );
  }
}
