import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Signs in with email and password.
  ///
  /// Preserved for existing callers.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs in and returns the authenticated user's UID and role.
  ///
  /// Expected result:
 /// Example result:
  /// - userId: the authenticated Firebase UID
  /// - role: either `asha` or `patient`
  ///
  /// Throws a StateError if the Firestore profile is missing or its
  /// role is invalid. The user is signed out in either case.
  Future<Map<String, String>> signInWithRole({
    required String email,
    required String password,
  }) async {
    final credential = await signIn(email: email, password: password);
    final user = credential.user;

    if (user == null) {
      throw StateError('Sign-in succeeded without a user account.');
    }

    try {
      final profile = await getUserProfile(user.uid);

      if (profile == null) {
        throw StateError(
          'Your user profile is missing. Please contact the administrator.',
        );
      }

      final role = profile['role'];

      if (role != 'asha' && role != 'patient') {
        throw StateError(
          'Your account role is missing or invalid. Please contact the administrator.',
        );
      }

      return {'userId': user.uid, 'role': role as String};
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  /// Currently authenticated Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Retrieves the Firestore profile for a UID.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final document = await _firestore.collection('users').doc(uid).get();

    if (!document.exists) {
      return null;
    }

    return {...document.data()!, 'id': document.id};
  }

  /// Retrieves the current user's role from their Firestore profile.
  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    final profile = await getUserProfile(user.uid);
    final role = profile?['role'];

    if (role == 'asha' || role == 'patient') {
      return role as String;
    }

    return null;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
