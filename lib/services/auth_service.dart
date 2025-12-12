import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:attendanceapp/services/theme_service.dart';

class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// User status values:
  /// - 'incomplete': Social login user who hasn't completed profile (needs role, studentId)
  /// - 'pending': Registered user awaiting admin/teacher approval
  /// - 'approved': Account approved by admin/teacher (can access app)
  /// - 'rejected': Account rejected by admin/teacher
  /// - '' (empty): Legacy accounts created before status field (treated as approved)

  /// Emits Firebase user only after hydration sets User.role/email/studentId.
  Stream<fb.User?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((u) async {
      if (u == null) {
        return null;
      }
      // If role already populated for same uid, skip re-hydration.
      if (User.uid != u.uid || User.role.isEmpty) {
        await _hydrateUser(u);
      }
      return u;
    });
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _hydrateUser(cred.user);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Login failed';
    }
  }

  Future<String?> register({
    required String email,
    required String password,
    required String role,
    String? studentId,
    String? teacherId,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final data = {
        'uid': uid,
        'email': email,
        'role': role,
        'status': 'incomplete', // proceed to complete profile first
        if (studentId != null && studentId.trim().isNotEmpty)
          'studentId': studentId.trim(),
        if (teacherId != null && teacherId.trim().isNotEmpty)
          'teacherId': teacherId.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('Users').doc(uid).set(data);

      // Manually set User fields immediately for new registration
      User.uid = uid;
      User.email = email;
      User.role = role;
      User.status = 'incomplete';
      User.studentId = studentId ?? '';
      // For teacher we mirror teacherId into studentId field only if needed elsewhere; keep distinct in Firestore
      if (role == 'teacher' &&
          teacherId != null &&
          teacherId.trim().isNotEmpty) {
        // No separate in-memory field defined; could extend User model later.
      }

      if (role == 'student' &&
          studentId != null &&
          studentId.trim().isNotEmpty) {
        // Ensure student collection doc exists for attendance
        final studentQuery = await _db
            .collection('Student')
            .where('id', isEqualTo: studentId.trim())
            .limit(1)
            .get();
        if (studentQuery.docs.isEmpty) {
          await _db.collection('Student').add({
            'id': studentId.trim(),
            'email': email,
          });
        }
      }

      print('=== USER REGISTERED ===');
      print('Email: ${User.email}');
      print('Role: ${User.role}');
      print('Status: ${User.status}');
      print('======================');

      return null;
    } on fb.FirebaseAuthException catch (e) {
      // Recovery path: if email already in use, attempt sign-in and create missing Firestore doc / update role.
      if (e.code == 'email-already-in-use') {
        try {
          final loginCred = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          final uid = loginCred.user!.uid;
          final existing = await _db.collection('Users').doc(uid).get();
          if (!existing.exists) {
            // Create user doc now with desired role
            await _db.collection('Users').doc(uid).set({
              'uid': uid,
              'email': email,
              'role': role,
              'status': 'incomplete',
              if (studentId != null && studentId.trim().isNotEmpty)
                'studentId': studentId.trim(),
              if (teacherId != null && teacherId.trim().isNotEmpty)
                'teacherId': teacherId.trim(),
              'createdAt': FieldValue.serverTimestamp(),
              'recoveredFromEmailInUse': true,
            });
          } else {
            // Update role if different and set status back to pending for approval if changing.
            final prevRole = existing.data()?['role'] ?? '';
            if (prevRole != role) {
              await _db.collection('Users').doc(uid).set({
                'role': role,
                'status': 'incomplete',
                if (teacherId != null && teacherId.trim().isNotEmpty)
                  'teacherId': teacherId.trim(),
                if (studentId != null && studentId.trim().isNotEmpty)
                  'studentId': studentId.trim(),
                'roleChangedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }
          await _hydrateUser(loginCred.user);
          return null; // Treat as success
        } catch (signErr) {
          return _mapAuthError(
            e,
          ); // Fallback original error message if sign-in fails
        }
      }
      return _mapAuthError(e);
    } catch (e) {
      return 'Registration failed';
    }
  }

  Future<void> signOut({ThemeService? themeService}) async {
    print('[SIGNOUT] Starting sign-out sequence');
    // Sign out from Firebase
    await _auth.signOut();
    print('[SIGNOUT] Firebase signOut complete');

    // Sign out from Google Sign-In if user was signed in with Google
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
        await googleSignIn
            .disconnect(); // Fully disconnect to force account picker next time
      }
    } catch (e) {
      print('[SIGNOUT] Google sign out error: $e');
    }

    // Reset theme to default (light mode)
    if (themeService != null) {
      await themeService.resetTheme();
      print('[SIGNOUT] Theme reset to default');
    }

    // Clear user data
    User.uid = '';
    User.role = '';
    User.email = '';
    User.id = ' ';
    User.studentId = ' ';
    User.status = '';
    User.fcmToken = '';
    print('[SIGNOUT] Local user cache cleared');
  }

  Future<void> _hydrateUser(fb.User? fUser) async {
    if (fUser == null) return;
    try {
      final doc = await _db
          .collection('Users')
          .doc(fUser.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists) return;
      final data = doc.data()!;
      User.uid = fUser.uid;
      User.email = fUser.email ?? '';
      User.role = (data['role'] ?? '').toString();
      User.studentId = (data['studentId'] ?? '').toString();
      User.status = (data['status'] ?? '').toString();
      User.fcmToken = (data['fcmToken'] ?? '').toString();
      User.providers = List<String>.from(data['providers'] ?? []);

      print('=== USER HYDRATED ===');
      print('Email: ${User.email}');
      print('Role: ${User.role}');
      print('Status: ${User.status}');
      print('==================');

      if (User.role == 'student' && User.studentId.trim().isNotEmpty) {
        // Resolve student Firestore document id for attendance
        try {
          final studentQuery = await _db
              .collection('Student')
              .where('id', isEqualTo: User.studentId.trim())
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));
          if (studentQuery.docs.isNotEmpty) {
            User.id = studentQuery.docs.first.id;
          }
        } catch (e) {
          // Non-critical: Skip if Student query fails
          print('Warning: Failed to fetch Student doc: $e');
        }
      }
    } catch (e) {
      print('Error hydrating user: $e');
    }
  }

  // --- Social Auth ---
  Future<String?> signInWithGoogle({
    String? desiredRole, // 'student' or 'teacher'
    String? studentId,
    String? teacherId,
  }) async {
    try {
      if (kIsWeb) {
        // Web: try popup flow first; if the browser blocks popups or
        // Cross-Origin-Opener-Policy prevents closing the popup, fall
        // back to a redirect flow which is more compatible.
        final provider = fb.GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        try {
          final cred = await _auth.signInWithPopup(provider);
          await _postSocialLogin(cred.user, provider: 'google');
          return null;
        } catch (e) {
          // Popup failed (possibly blocked by COOP/COEP or browser policy).
          // Fallback to redirect sign-in which opens in the same tab.
          print('Web popup sign-in failed, falling back to redirect: $e');
          try {
            await _auth.signInWithRedirect(provider);
            // No immediate credential produced; the redirect flow will
            // complete after navigation. Return null to indicate the
            // operation was started.
            return null;
          } catch (e2) {
            print('Web redirect sign-in also failed: $e2');
            return 'Google sign-in failed: ${e2.toString()}';
          }
        }
      }
      // Android/iOS: use google_sign_in plugin for more reliable native flow
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

      // Force sign out and disconnect to show account picker every time
      try {
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
          await googleSignIn.disconnect();
        }
      } catch (e) {
        // Ignore if already signed out
        print('Pre-signin cleanup: $e');
      }

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'Google sign-in canceled';
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      await _postSocialLogin(
        cred.user,
        provider: 'google',
        desiredRole: desiredRole,
        studentId: studentId,
        teacherId: teacherId,
      );
      return null;
    } on fb.FirebaseAuthException catch (e) {
      print('Google login FirebaseAuthException: ${e.code} - ${e.message}');
      return _mapAuthError(e);
    } catch (e) {
      print('Google login failed: $e');
      return 'Google login failed';
    }
  }

  Future<void> _postSocialLogin(
    fb.User? user, {
    required String provider,
    String? desiredRole,
    String? studentId,
    String? teacherId,
  }) async {
    if (user == null) return;
    final ref = _db.collection('Users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'providers': [provider],
        'status': 'incomplete', // will complete credentials next
        if (desiredRole != null) 'role': desiredRole,
        if (desiredRole == 'student' &&
            studentId != null &&
            studentId.trim().isNotEmpty)
          'studentId': studentId.trim(),
        if (desiredRole == 'teacher' &&
            teacherId != null &&
            teacherId.trim().isNotEmpty)
          'teacherId': teacherId.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'providers': FieldValue.arrayUnion([provider]),
        // If role not set yet and caller supplies one, set it.
        if ((snap.data()?['role'] ?? '').toString().isEmpty &&
            desiredRole != null)
          'role': desiredRole,
        if (desiredRole == 'student' &&
            studentId != null &&
            studentId.trim().isNotEmpty)
          'studentId': studentId.trim(),
        if (desiredRole == 'teacher' &&
            teacherId != null &&
            teacherId.trim().isNotEmpty)
          'teacherId': teacherId.trim(),
      }, SetOptions(merge: true));
    }
    await _hydrateUser(user);
  }

  Future<String?> completeCredentials({
    required String role,
    String? studentId,
    String? teacherId,
  }) async {
    try {
      if (User.uid.isEmpty) return 'Not signed in';
      final update = {
        'role': role,
        'status': 'pending', // move to pending approval after completion
        if (studentId != null && studentId.trim().isNotEmpty)
          'studentId': studentId.trim(),
        if (teacherId != null && teacherId.trim().isNotEmpty)
          'teacherId': teacherId.trim(),
      };
      await _db
          .collection('Users')
          .doc(User.uid)
          .set(update, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      // If student ensure Student collection doc
      if (role == 'student' &&
          studentId != null &&
          studentId.trim().isNotEmpty) {
        final q = await _db
            .collection('Student')
            .where('id', isEqualTo: studentId.trim())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
        if (q.docs.isEmpty) {
          await _db
              .collection('Student')
              .add({'id': studentId.trim(), 'email': User.email})
              .timeout(const Duration(seconds: 10));
        }
      }
      // If teacher ensure Teacher collection doc
      if (role == 'teacher' &&
          teacherId != null &&
          teacherId.trim().isNotEmpty) {
        final q = await _db
            .collection('Teacher')
            .where('id', isEqualTo: teacherId.trim())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
        if (q.docs.isEmpty) {
          await _db
              .collection('Teacher')
              .add({'id': teacherId.trim(), 'email': User.email})
              .timeout(const Duration(seconds: 10));
        }
      }

      // Try to hydrate user, but don't fail if it times out
      try {
        await _hydrateUser(
          _auth.currentUser,
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        print('Warning: Failed to hydrate user during completeCredentials: $e');
        // Non-critical: Continue even if hydration fails
      }

      return null;
    } catch (e) {
      print('Error in completeCredentials: $e');
      return 'Credential completion failed: ${e.toString()}';
    }
  }

  // Request a role change (e.g., student -> teacher). Sets status to pending for approval.
  Future<String?> requestRoleChange({
    required String newRole,
    String? teacherId,
  }) async {
    try {
      final u = _auth.currentUser;
      if (u == null) return 'Not signed in';
      if (newRole != 'teacher' && newRole != 'student' && newRole != 'admin') {
        return 'Invalid role';
      }
      final update = <String, dynamic>{
        'role': newRole,
        'status': 'pending',
        if (teacherId != null && teacherId.trim().isNotEmpty)
          'teacherId': teacherId.trim(),
        'roleChangedAt': FieldValue.serverTimestamp(),
      };
      await _db
          .collection('Users')
          .doc(u.uid)
          .set(update, SetOptions(merge: true));
      // Hydrate new role/status locally
      User.role = newRole;
      User.status = 'pending';
      if (teacherId != null) {
        User.studentId = teacherId; // Keep existing field mapping minimal
      }
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Role change failed';
    }
  }

  String _mapAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Account not found. Use Register.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email already in use. If you meant to create a teacher account, sign in with this email and (if status is incomplete) finish credentials instead of registering again.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'weak-password':
        return 'Password too weak (min 6 chars).';
      case 'network-request-failed':
        return 'Network error. Check connection.';
      case 'too-many-requests':
        return 'Too many attempts. Try later.';
      case 'internal-error':
        return 'Internal auth error. Re-check Firebase setup.';
      default:
        return e.message ?? 'Authentication error (${e.code}).';
    }
  }
}
