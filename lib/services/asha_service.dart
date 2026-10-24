import 'package:cloud_firestore/cloud_firestore.dart';

class AshaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the ASHA worker's name and phone number.
  ///
  /// Returns null when the profile does not exist or is not an ASHA.
  Future<Map<String, dynamic>?> getAshaContact(String ashaUid) async {
    if (ashaUid.trim().isEmpty) return null;

    final document = await _firestore.collection('users').doc(ashaUid).get();

    if (!document.exists) return null;

    final data = document.data()!;

    if (data['role'] != 'asha') return null;

    return {
      'id': document.id,
      'name': data['name']?.toString() ?? '',
      'phone': data['phone']?.toString() ?? '',
    };
  }
}
