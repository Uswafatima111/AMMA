import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Stores reminder instructions only. This service does not schedule or deliver
/// local notifications, push notifications, or alarms.
class ReminderService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ReminderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static void validateReminder({
    required String motherId,
    required String medicineName,
    required String instructions,
    required DateTime startDate,
    required DateTime endDate,
    required String reminderTime,
  }) {
    if (motherId.trim().isEmpty ||
        motherId.length > 200 ||
        medicineName.trim().isEmpty ||
        instructions.trim().isEmpty) {
      throw ArgumentError(
        'Mother, medicine name, and supplied instructions are required.',
      );
    }
    if (medicineName.length > 120 || instructions.length > 1000) {
      throw ArgumentError('Reminder text exceeds the supported length.');
    }
    if (_dateOnly(startDate).isAfter(_dateOnly(endDate))) {
      throw ArgumentError('Reminder end date must not precede its start date.');
    }
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(reminderTime)) {
      throw ArgumentError('Reminder time must use 24-hour HH:mm format.');
    }
  }

  static String reminderDocumentId({
    required String motherId,
    required String medicineName,
    required DateTime startDate,
    required DateTime endDate,
    required String reminderTime,
  }) {
    final identity = [
      motherId.trim(),
      medicineName.trim().toLowerCase(),
      _dateOnly(startDate).toIso8601String(),
      _dateOnly(endDate).toIso8601String(),
      reminderTime,
    ].join('|');
    return 'rem_${base64Url.encode(utf8.encode(identity)).replaceAll('=', '')}';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static bool isAssignedAsha({
    required String uid,
    required String role,
    required String? assignedAshaId,
  }) => uid.isNotEmpty && role == 'asha' && assignedAshaId == uid;

  String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required.');
    }
    return uid;
  }

  Future<void> _requireAssignedAsha(String uid, String motherId) async {
    final user = await _firestore.collection('users').doc(uid).get();
    if (!user.exists || user.data()?['role'] != 'asha') {
      throw StateError('An authenticated ASHA profile is required.');
    }
    final mother = await _firestore.collection('mothers').doc(motherId).get();
    if (!mother.exists || mother.data()?['assignedAshaId'] != uid) {
      throw StateError('Mother is not assigned to this ASHA.');
    }
  }

  /// Creates one stored reminder. Instructions are supplied by the ASHA;
  /// no medicine, dose, or frequency is recommended by this service.
  Future<String> createReminder({
    required String motherId,
    required String medicineName,
    required String instructions,
    required DateTime startDate,
    required DateTime endDate,
    required String reminderTime,
  }) async {
    validateReminder(
      motherId: motherId,
      medicineName: medicineName,
      instructions: instructions,
      startDate: startDate,
      endDate: endDate,
      reminderTime: reminderTime,
    );
    final uid = _uid();
    await _requireAssignedAsha(uid, motherId);
    final id = reminderDocumentId(
      motherId: motherId,
      medicineName: medicineName,
      startDate: startDate,
      endDate: endDate,
      reminderTime: reminderTime,
    );
    final ref = _firestore.collection('medicine_reminders').doc(id);
    await ref.set({
      'motherId': motherId,
      'medicineName': medicineName.trim(),
      'instructions': instructions.trim(),
      'startDate': Timestamp.fromDate(_dateOnly(startDate)),
      'endDate': Timestamp.fromDate(_dateOnly(endDate)),
      'reminderTime': reminderTime,
      'active': true,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchForMother(String motherId) {
    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }
    return _firestore
        .collection('medicine_reminders')
        .where('motherId', isEqualTo: motherId)
        .snapshots();
  }

  Future<void> setActive({
    required String reminderId,
    required bool active,
  }) async {
    final uid = _uid();
    final ref = _firestore.collection('medicine_reminders').doc(reminderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Medicine reminder not found.');
      final data = snapshot.data()!;
      final motherId = data['motherId'];
      if (motherId is! String || motherId.isEmpty) {
        throw StateError('Reminder mother is missing.');
      }
      final user = await transaction.get(
        _firestore.collection('users').doc(uid),
      );
      final mother = await transaction.get(
        _firestore.collection('mothers').doc(motherId),
      );
      if (!user.exists ||
          !mother.exists ||
          !isAssignedAsha(
            uid: uid,
            role: user.data()?['role']?.toString() ?? '',
            assignedAshaId: mother.data()?['assignedAshaId'] as String?,
          )) {
        throw StateError(
          'Only the ASHA assigned to this mother can update reminders.',
        );
      }
      transaction.update(ref, {
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
