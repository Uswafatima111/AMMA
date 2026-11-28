import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AshaService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AshaService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Returns the assigned ASHA's public name and phone number for a patient.
  ///
  /// ASHAs can retrieve their own contact from their private profile. Patient
  /// callers are resolved through their linked mother and read only the
  /// separate, limited `asha_contacts` projection. Admin SDK access is not
  /// subject to these client security rules.
  Future<Map<String, dynamic>?> getAshaContact([String? ashaUid]) async {
    final callerUid = _auth.currentUser?.uid;
    if (callerUid == null || callerUid.isEmpty) return null;

    final callerProfile = await _firestore
        .collection('users')
        .doc(callerUid)
        .get();
    if (!callerProfile.exists) return null;
    final callerData = callerProfile.data()!;
    final role = callerData['role'];

    if (role == 'asha') {
      if (ashaUid != null && ashaUid.trim() != callerUid) return null;
      return _contact(callerUid, callerData);
    }
    if (role != 'patient') return null;

    final mother = await _getLinkedMother(callerUid, callerData);
    if (mother == null) return null;
    final motherData = mother.data()!;
    if (motherData['patientUid'] != callerUid && mother.id != callerUid) {
      return null;
    }

    final assignedAshaId = motherData['assignedAshaId'];
    if (assignedAshaId is! String || assignedAshaId.isEmpty) return null;
    if (ashaUid != null && ashaUid.trim() != assignedAshaId) return null;

    final contact = await _firestore
        .collection('asha_contacts')
        .doc(assignedAshaId)
        .get();
    if (!contact.exists) return null;
    final data = contact.data()!;
    if (data['id'] != assignedAshaId ||
        data.keys.any((key) => !{'id', 'name', 'phone'}.contains(key))) {
      return null;
    }
    return _contact(assignedAshaId, data);
  }

  /// Publishes the authenticated ASHA's limited contact projection.
  ///
  /// The matching Firestore rule permits writes only to the caller's own
  /// projection and requires the values to match that ASHA's profile.
  Future<void> publishOwnContact() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required.');
    }
    final profile = await _firestore.collection('users').doc(uid).get();
    final data = profile.data();
    if (!profile.exists || data?['role'] != 'asha') {
      throw StateError('An ASHA profile is required.');
    }
    await _firestore.collection('asha_contacts').doc(uid).set({
      'id': uid,
      'name': data?['name']?.toString() ?? '',
      'phone': data?['phone']?.toString() ?? '',
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getLinkedMother(
    String patientUid,
    Map<String, dynamic> patientProfile,
  ) async {
    final assignedMotherId = patientProfile['assignedMotherId'];
    if (assignedMotherId is String && assignedMotherId.isNotEmpty) {
      final mother = await _firestore
          .collection('mothers')
          .doc(assignedMotherId)
          .get();
      return mother.exists ? mother : null;
    }
    final legacy = await _firestore.collection('mothers').doc(patientUid).get();
    return legacy.exists ? legacy : null;
  }

  Map<String, dynamic> _contact(String uid, Map<String, dynamic> data) => {
    'id': uid,
    'name': data['name']?.toString() ?? '',
    'phone': data['phone']?.toString() ?? '',
  };
}
