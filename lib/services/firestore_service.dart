import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get a mother's profile.
  Future<Map<String, dynamic>?> getMother(String userId) async {
    final document =
        await _firestore.collection('mothers').doc(userId).get();

    if (!document.exists) {
      return null;
    }

    return document.data();
  }

  // Get all mothers.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMothers() {
    return _firestore
        .collection('mothers')
        .orderBy('name')
        .snapshots();
  }

  // Create a mother's profile.
  Future<void> createMother({
    required String userId,
    required String name,
    required int pregnancyWeek,
    required String status,
  }) async {
    await _firestore.collection('mothers').doc(userId).set({
      'userId': userId,
      'name': name,
      'pregnancyWeek': pregnancyWeek,
      'status': status,
    });
  }

  // Update a mother's profile.
  Future<void> updateMother({
    required String userId,
    String? name,
    int? pregnancyWeek,
    String? status,
  }) async {
    final data = <String, dynamic>{};

    if (name != null) {
      data['name'] = name;
    }

    if (pregnancyWeek != null) {
      data['pregnancyWeek'] = pregnancyWeek;
    }

    if (status != null) {
      data['status'] = status;
    }

    if (data.isNotEmpty) {
      await _firestore.collection('mothers').doc(userId).update(data);
    }
  }

  // Delete a mother's profile.
  Future<void> deleteMother(String userId) async {
    await _firestore.collection('mothers').doc(userId).delete();
  }
}