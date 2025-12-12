import 'package:attendanceapp/homescreen.dart';
import 'package:attendanceapp/admin_home.dart';
import 'package:attendanceapp/teacher_home.dart';
import 'package:attendanceapp/services/auth_service.dart';
import 'package:attendanceapp/services/messaging_service.dart';
import 'package:attendanceapp/services/theme_service.dart';
import 'package:attendanceapp/config/app_theme.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:attendanceapp/login_page.dart';
import 'package:attendanceapp/pending_verification_screen.dart';
import 'package:attendanceapp/complete_credentials_screen.dart';
import 'package:attendanceapp/loading_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
// Removed unused SharedPreferences import and duplicate user import.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    // Native (Android/iOS) App Check activation. Run in background with
    // a short timeout so missing device services don't block app startup.
    Future(() async {
      try {
        await FirebaseAppCheck.instance
            .activate(androidProvider: AndroidProvider.playIntegrity)
            .timeout(const Duration(seconds: 3));
        // ignore: avoid_print
        print('App Check activated');
      } catch (e) {
        // Ignore App Check activation failures to avoid startup ANR.
        // Log for debugging.
        // ignore: avoid_print
        print('App Check activation failed or timed out: $e');
      }
    });
  } else {
    // Web: App Check is initialized via JS in web/index.html (reCAPTCHA v3).
  }

  // Start the Flutter app immediately to avoid blocking the main thread
  // during remote initialization steps.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.initialize();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ThemeServiceProvider(
      themeService: _themeService,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Attendance App',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeService.themeMode,
        home: KeyboardVisibilityProvider(child: const AuthCheck()),
      ),
    );
  }
}

/// InheritedWidget to provide ThemeService throughout the app
class ThemeServiceProvider extends InheritedWidget {
  final ThemeService themeService;

  const ThemeServiceProvider({
    super.key,
    required this.themeService,
    required super.child,
  });

  static ThemeService of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<ThemeServiceProvider>();
    assert(provider != null, 'No ThemeServiceProvider found in context');
    return provider!.themeService;
  }

  @override
  bool updateShouldNotify(ThemeServiceProvider oldWidget) {
    return themeService != oldWidget.themeService;
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder(
      stream: auth.authStateChanges().handleError((e, st) {
        // Log but don't let auth stream errors crash the app during web debugging.
        // This prevents Dart exceptions from being forwarded into JS interop
        // code where they can cause type-check failures.
        // ignore: avoid_print
        print('authStateChanges ERROR: $e');
        // ignore: avoid_print
        print(st);
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final fbUser = snapshot.data;
        if (fbUser == null) {
          return const LoginPage();
        }
        // Route incomplete status BEFORE checking for role.
        // If role is known (from registration), send to role-specific profile screen.
        if (User.status == 'incomplete') {
          if (User.role == 'student') {
            return const CompleteCredentialsScreen(forcedRole: 'student');
          } else if (User.role == 'teacher') {
            return const CompleteCredentialsScreen(forcedRole: 'teacher');
          } else {
            // Social users may not have a role yet; show the chooser
            return const CompleteCredentialsScreen();
          }
        }
        // Pending verification screen.
        if (User.status == 'pending') {
          // Initialize messaging service to capture token for notification.
          // On web, FCM requires extra setup (service worker). Skip during
          // web debugging to avoid interop crashes; initialize on non-web.
          try {
            if (!kIsWeb) {
              MessagingService().initialize();
            } else {
              // ignore: avoid_print
              print('Skipping MessagingService.initialize() on web (dev).');
            }
          } catch (e, st) {
            // ignore: avoid_print
            print('MessagingService.initialize ERROR: $e');
            // ignore: avoid_print
            print(st);
          }
          return const PendingVerificationScreen();
        }
        // Approved or legacy accounts (empty status) can proceed
        // Only 'incomplete' and 'pending' should block access
        // Rare race: user doc loaded but role still empty (non-incomplete/pending)
        if (User.role.isEmpty) {
          return const LoadingScreen();
        }
        switch (User.role) {
          case 'student':
            return const Homescreen();
          case 'teacher':
            return const TeacherHome();
          case 'admin':
            return const AdminHome();
          default:
            return const LoginPage();
        }
      },
    );
  }
}
