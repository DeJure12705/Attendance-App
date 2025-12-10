import 'package:flutter/material.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/register_page.dart';
import 'package:attendanceapp/complete_credentials_screen.dart';
import 'package:attendanceapp/loading_screen.dart';
import 'package:attendanceapp/pending_verification_screen.dart';
import 'package:attendanceapp/homescreen.dart';
import 'package:attendanceapp/teacher_home.dart';
import 'package:attendanceapp/admin_home.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

// Email/password login page.
// Handles credential sign-in, Google sign-in, shows validation errors,
// and navigates to the appropriate next screen via AuthService state.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;
  bool _socialLoading = false;

  final AuthService _auth = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Validate form and perform email/password sign-in.
  // On success, we show a loading screen and let the auth stream route.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final err = await _auth.signIn(email: email, password: password);
    if (mounted) {
      if (err != null) {
        setState(() {
          _loading = false;
          _error = err;
        });
      } else {
        // Login successful - auth stream will handle navigation
        print('Login successful - Email: $email');
        // Release loading state so UI isn't stuck if navigation is delayed
        setState(() {
          _loading = false;
        });
        // Show full-screen loading while waiting for stream routing
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoadingScreen()),
        );
      }
    }
  }

  // Kick off Google sign-in and route based on role/status.
  // Pushes a loading screen while AuthService completes.
  Future<void> _googleLogin() async {
    setState(() {
      _socialLoading = true;
      _error = null;
    });
    // Show loading screen immediately (push, not replace) so user sees progress.
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoadingScreen()));
    final err = await _auth.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _socialLoading = false;
      _error = err;
    });
    if (err == null) {
      final current = fb.FirebaseAuth.instance.currentUser;
      if (current != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        Widget? target;
        if (User.status == 'incomplete') {
          if (User.role == 'student') {
            target = const CompleteCredentialsScreen(forcedRole: 'student');
          } else if (User.role == 'teacher') {
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
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => target!),
            (route) => false,
          );
        }
      }
    } else {
      // Sign-in failed: pop loading screen if still present.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
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
                          // Header
                          const Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontFamily: 'NexaBold',
                              fontSize: 32,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to continue',
                            style: TextStyle(
                              fontFamily: 'NexaRegular',
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          // Email field
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
                          const SizedBox(height: 16),
                          // Password field with show/hide toggle
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
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v.length < 6) return 'At least 6 characters';
                              return null;
                            },
                          ),
                          // Error banner
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
                          // Submit button
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
                                      'Sign In',
                                      style: TextStyle(
                                        fontFamily: 'NexaBold',
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Divider + Social login
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
                          // Link to registration
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  "Don't have an account? ",
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
                                      builder: (_) => const RegisterPage(),
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
                                  'Register',
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
