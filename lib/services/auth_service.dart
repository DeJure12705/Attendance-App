import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/model/user.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
        'status': 'pending', // requires admin/teacher approval
        if (studentId != null && studentId.trim().isNotEmpty)
          'studentId': studentId.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('Users').doc(uid).set(data);
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
      await _hydrateUser(cred.user);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Registration failed';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    User.uid = '';
    User.role = '';
    User.email = '';
    User.id = ' ';
    User.studentId = ' ';
    User.status = '';
    User.fcmToken = '';
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
  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: OAuthProvider redirect/popup flow
        final provider = fb.OAuthProvider('google.com')
          ..addScope('email')
          ..addScope('profile');
        final cred = await _auth.signInWithProvider(provider);
        await _postSocialLogin(cred.user, provider: 'google');
        return null;
      }
      // Android/iOS: use google_sign_in plugin for more reliable native flow
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'Google sign-in canceled';
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      await _postSocialLogin(cred.user, provider: 'google');
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Google login failed';
    }
  }

  Future<String?> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        final provider = fb.OAuthProvider('facebook.com')..addScope('email');
        final cred = await _auth.signInWithProvider(provider);
        await _postSocialLogin(cred.user, provider: 'facebook');
        return null;
      }
      // Android/iOS native plugin flow
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success) {
        return 'Facebook sign-in failed (${result.status.name})';
      }
      final accessToken = result.accessToken;
      String? token = accessToken?.tokenString;
      if (token == null || token.isEmpty) {
        final map = accessToken?.toJson();
        final dynamic legacy = map != null ? map['token'] : null;
        if (legacy is String && legacy.isNotEmpty) token = legacy;
      }
      if (token == null || token.isEmpty) {
        return 'Facebook access token missing';
      }
      final credential = fb.FacebookAuthProvider.credential(token);
      final cred = await _auth.signInWithCredential(credential);
      await _postSocialLogin(cred.user, provider: 'facebook');
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Facebook login failed';
    }
  }

  Future<void> _postSocialLogin(
    fb.User? user, {
    required String provider,
  }) async {
    if (user == null) return;
    final ref = _db.collection('Users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'providers': [provider],
        'status': 'incomplete', // Need role & (studentId if student)
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'providers': FieldValue.arrayUnion([provider]),
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

  String _mapAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Account not found. Use Register.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email already registered.';
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
