import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in an existing user.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Get the currently authenticated user.
  User? get currentUser => _auth.currentUser;

  // Get a user's Firestore profile.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final document =
        await _firestore.collection('users').doc(uid).get();

    if (!document.exists) {
      return null;
    }

    return document.data();
  }

  // Get the current user's role.
  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final profile = await getUserProfile(user.uid);

    return profile?['role'] as String?;
  }

  // Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Listen for authentication changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}