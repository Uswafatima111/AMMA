import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_enums.dart';

class ReferralService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  ReferralService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static bool canTransition(ReferralStatus from, ReferralStatus to) =>
      (from == ReferralStatus.pending &&
          {ReferralStatus.accepted, ReferralStatus.cancelled}.contains(to)) ||
      (from == ReferralStatus.accepted &&
          {ReferralStatus.completed, ReferralStatus.cancelled}.contains(to));

  static bool canAccessReferral({
    required String authenticatedUid,
    required String role,
    required String? motherAssignedAshaId,
  }) =>
      authenticatedUid.isNotEmpty &&
      role == 'asha' &&
      motherAssignedAshaId == authenticatedUid;

  static void validateTransition(ReferralStatus from, ReferralStatus to) {
    if (!canTransition(from, to)) {
      throw StateError(
        'Invalid referral status transition: ${from.name} -> ${to.name}.',
      );
    }
  }

  String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required.');
    }
    return uid;
  }

  Future<void> _requireAsha(String uid) async {
    final profile = await _firestore.collection('users').doc(uid).get();
    if (!profile.exists || profile.data()?['role'] != 'asha') {
      throw StateError('An authenticated ASHA profile is required.');
    }
  }

  Future<String> createReferral({
    required String motherId,
    required String facility,
  }) async {
    final uid = _uid();
    await _requireAsha(uid);
    if (motherId.trim().isEmpty || facility.trim().isEmpty) {
      throw ArgumentError('Mother and facility are required.');
    }
    final mother = await _firestore.collection('mothers').doc(motherId).get();
    if (!mother.exists || mother.data()?['assignedAshaId'] != uid) {
      throw StateError('Mother is not assigned to this ASHA.');
    }
    final ref = _firestore.collection('referrals').doc();
    await ref.set({
      'motherId': motherId,
      'referringAshaId': uid,
      'facility': facility.trim(),
      'status': ReferralStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'acceptedAt': null,
      'completedAt': null,
      'cancelledAt': null,
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchForMother(
    String motherId,
  ) async* {
    final uid = _uid();
    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }
    await _requireAsha(uid);
    final mother = await _firestore.collection('mothers').doc(motherId).get();
    if (!mother.exists ||
        !canAccessReferral(
          authenticatedUid: uid,
          role: 'asha',
          motherAssignedAshaId: mother.data()?['assignedAshaId'] as String?,
        )) {
      throw StateError('Mother is not assigned to this ASHA.');
    }
    yield* _firestore
        .collection('referrals')
        .where('motherId', isEqualTo: motherId)
        .snapshots();
  }

  Future<void> updateStatus({
    required String referralId,
    required ReferralStatus status,
  }) async {
    final uid = _uid();
    await _requireAsha(uid);
    final ref = _firestore.collection('referrals').doc(referralId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Referral not found.');
      final data = snapshot.data()!;
      final motherId = data['motherId'];
      if (motherId is! String || motherId.isEmpty) {
        throw StateError('Referral mother is missing.');
      }
      final motherRef = _firestore.collection('mothers').doc(motherId);
      final mother = await transaction.get(motherRef);
      if (!mother.exists ||
          !canAccessReferral(
            authenticatedUid: uid,
            role: 'asha',
            motherAssignedAshaId: mother.data()?['assignedAshaId'] as String?,
          )) {
        throw StateError('Mother is not assigned to this ASHA.');
      }
      final current = ReferralStatus.values
          .where((v) => v.name == data['status'])
          .firstOrNull;
      if (current == null) throw StateError('Referral status is invalid.');
      validateTransition(current, status);
      final now = FieldValue.serverTimestamp();
      final key = switch (status) {
        ReferralStatus.accepted => 'acceptedAt',
        ReferralStatus.completed => 'completedAt',
        ReferralStatus.cancelled => 'cancelledAt',
        ReferralStatus.pending => throw StateError(
          'Cannot transition to pending.',
        ),
      };
      transaction.update(ref, {
        'status': status.name,
        'updatedAt': now,
        key: now,
      });
    });
  }
}
