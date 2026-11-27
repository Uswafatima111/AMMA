import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppointmentService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const appointmentTypes = {'routine', 'followUp', 'emergency'};
  static const initialStatuses = {'scheduled', 'pending'};

  static bool canTransition(String from, String to) =>
      (from == 'pending' && {'scheduled', 'cancelled'}.contains(to)) ||
      (from == 'scheduled' && {'completed', 'cancelled'}.contains(to));

  static bool patientOwnsAppointment({
    required String authenticatedUid,
    required String patientId,
  }) => authenticatedUid.isNotEmpty && authenticatedUid == patientId;

  static bool isPatientOwnedAppointmentQuery({
    required String authenticatedUid,
    required String userId,
  }) => authenticatedUid.isNotEmpty && authenticatedUid == userId;

  static List<String> matchingAssignedMotherIds({
    required String suppliedUserId,
    required Iterable<Map<String, dynamic>> assignedMothers,
  }) => assignedMothers
      .where(
        (mother) =>
            mother['id'] == suppliedUserId ||
            mother['userId'] == suppliedUserId ||
            mother['patientUid'] == suppliedUserId,
      )
      .map((mother) => mother['id'] as String)
      .toList();

  static bool isHistoryAppointment({
    required String status,
    required DateTime appointmentDate,
    required DateTime now,
  }) =>
      {'completed', 'cancelled'}.contains(status) ||
      !appointmentDate.isAfter(now);

  static bool isAssignedAsha({
    required String authenticatedUid,
    required String role,
    required String? assignedAshaId,
  }) =>
      authenticatedUid.isNotEmpty &&
      role == 'asha' &&
      assignedAshaId == authenticatedUid;

  static void validateStatusTransition(String from, String to) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid appointment status transition: $from -> $to.');
    }
  }

  static void validateAppointment({
    required String motherId,
    required DateTime date,
    required String type,
    required String status,
  }) {
    if (motherId.trim().isEmpty || motherId.length > 200) {
      throw ArgumentError('motherId is missing or too long.');
    }
    if (!appointmentTypes.contains(type)) {
      throw ArgumentError('Appointment type is invalid.');
    }
    if (!initialStatuses.contains(status)) {
      throw ArgumentError('Initial appointment status is invalid.');
    }
  }

  static String appointmentDocumentId({
    required String motherId,
    required DateTime date,
    required String type,
    required String doctorName,
    required String facilityName,
    String appointmentKey = '',
  }) {
    final identity = [
      motherId.trim(),
      date.toUtc().microsecondsSinceEpoch.toString(),
      type,
      doctorName.trim().toLowerCase(),
      facilityName.trim().toLowerCase(),
      appointmentKey.trim().toLowerCase(),
    ].join('|');
    return 'appt_${base64Url.encode(utf8.encode(identity)).replaceAll('=', '')}';
  }

  String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required.');
    }
    return uid;
  }

  Future<String> _role(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final role = snapshot.data()?['role'];
    if (!snapshot.exists || (role != 'asha' && role != 'patient')) {
      throw StateError('A valid user profile is required.');
    }
    return role as String;
  }

  Future<void> _requireAssignedAsha(String uid, String motherId) async {
    if (await _role(uid) != 'asha') {
      throw StateError('An ASHA account is required.');
    }
    final mother = await _firestore.collection('mothers').doc(motherId).get();
    if (!mother.exists || mother.data()?['assignedAshaId'] != uid) {
      throw StateError('Mother is not assigned to this ASHA.');
    }
  }

  Future<void> _createWithoutOverwrite(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    try {
      await ref.set(data);
    } catch (error) {
      try {
        if ((await ref.get()).exists) {
          throw StateError('Duplicate appointment already exists.');
        }
      } on StateError {
        rethrow;
      } catch (_) {
        // Preserve the original write error if read-back is not allowed or
        // Firestore is unavailable.
      }
      rethrow;
    }
  }

  /// Legacy appointment creation retained for existing callers.
  Future<void> createAppointment({
    required String userId,
    required String title,
    required String doctorName,
    required DateTime date,
    String? notes,
  }) async {
    final uid = _uid();
    if (!patientOwnsAppointment(authenticatedUid: uid, patientId: userId) ||
        await _role(uid) != 'patient') {
      throw StateError('Patients may create appointments only for themselves.');
    }
    if (title.trim().isEmpty ||
        !date.isAfter(DateTime.now()) ||
        title.length > 200 ||
        doctorName.length > 200 ||
        (notes?.length ?? 0) > 2000) {
      throw ArgumentError(
        'Appointment details must be valid and date must be future.',
      );
    }
    final id = appointmentDocumentId(
      motherId: uid,
      date: date,
      type: 'routine',
      doctorName: doctorName,
      facilityName: title,
    );
    final ref = _firestore.collection('appointments').doc(id);
    await _createWithoutOverwrite(ref, {
      'id': id,
      'userId': uid,
      'title': title.trim(),
      'doctorName': doctorName.trim(),
      'date': Timestamp.fromDate(date),
      'type': 'routine',
      'status': 'pending',
      'notes': notes?.trim() ?? '',
      'reminderEnabled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Creates an appointment for a mother assigned to the authenticated ASHA.
  /// A deterministic identity prevents duplicate creation across concurrent
  /// clients for the same mother/date/type/doctor/facility tuple.
  Future<String> createAppointmentForMother({
    required String motherId,
    required DateTime date,
    required String type,
    required String doctorName,
    required String facilityName,
    bool reminderEnabled = true,
    String status = 'scheduled',
    String? notes,
    String appointmentKey = '',
  }) async {
    validateAppointment(
      motherId: motherId,
      date: date,
      type: type,
      status: status,
    );
    if (!date.isAfter(DateTime.now())) {
      throw ArgumentError('Appointment date must be in the future.');
    }
    if (doctorName.length > 200 ||
        facilityName.length > 200 ||
        (notes?.length ?? 0) > 2000 ||
        appointmentKey.length > 120) {
      throw ArgumentError('Appointment details exceed the supported length.');
    }
    final uid = _uid();
    await _requireAssignedAsha(uid, motherId);
    final id = appointmentDocumentId(
      motherId: motherId,
      date: date,
      type: type,
      doctorName: doctorName,
      facilityName: facilityName,
      appointmentKey: appointmentKey,
    );
    final ref = _firestore.collection('appointments').doc(id);
    await _createWithoutOverwrite(ref, {
      'id': id,
      'motherId': motherId,
      'date': Timestamp.fromDate(date),
      'type': type,
      'status': status,
      'reminderEnabled': reminderEnabled,
      'doctorName': doctorName.trim(),
      'facilityName': facilityName.trim(),
      'appointmentKey': appointmentKey.trim(),
      'notes': notes?.trim() ?? '',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Legacy query. Rules limit patient results to their own UID and ASHA
  /// results to mother records they are authorised to access.
  Stream<QuerySnapshot<Map<String, dynamic>>> getAppointments(String userId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.error(StateError('Authentication required.'));
    }
    final appointments = _firestore.collection('appointments');
    if (isPatientOwnedAppointmentQuery(authenticatedUid: uid, userId: userId)) {
      // This is the patient's own constrained legacy query.
      return appointments.where('userId', isEqualTo: uid).snapshots();
    }

    // ASHA legacy callers pass a mother's legacy userId. Resolve that value
    // only within mothers already constrained to this signed-in ASHA, then
    // query by the matched stable mother document ID. Never issue an
    // unconstrained userId query for another person's records.
    return _firestore
        .collection('mothers')
        .where('assignedAshaId', isEqualTo: uid)
        .snapshots()
        .asyncExpand((mothers) {
          final assignedMothers = mothers.docs.map(
            (mother) => {...mother.data(), 'id': mother.id},
          );
          final matches = matchingAssignedMotherIds(
            suppliedUserId: userId,
            assignedMothers: assignedMothers,
          );
          if (matches.length != 1) {
            return Stream<QuerySnapshot<Map<String, dynamic>>>.error(
              StateError(
                matches.isEmpty
                    ? 'No assigned mother matches this appointment query.'
                    : 'Multiple assigned mothers match this appointment query.',
              ),
            );
          }
          return appointments
              .where('motherId', isEqualTo: matches.single)
              .snapshots();
        });
  }

  /// Scoped stream supporting contract and legacy records without a full
  /// collection scan. The two queries are merged by document ID.
  Stream<List<Map<String, dynamic>>> watchAppointmentsForMother(
    String motherId,
  ) {
    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }
    final contractStream = _firestore
        .collection('appointments')
        .where('motherId', isEqualTo: motherId)
        .snapshots();
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.error(StateError('Authentication required.'));
    }
    // Constrain legacy results to the signed-in user's own UID. The former
    // userId == motherId ASHA query could include rows with unrelated motherId
    // values, which rules cannot safely filter after retrieval.
    final legacyStream = _firestore
        .collection('appointments')
        .where('userId', isEqualTo: uid)
        .snapshots();
    final controller = StreamController<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>>? contractRows;
    List<Map<String, dynamic>>? legacyRows;
    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> contractSub;
    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> legacySub;

    void emit() {
      if (contractRows == null || legacyRows == null) return;
      final merged = <String, Map<String, dynamic>>{};
      for (final row in [...contractRows!, ...legacyRows!]) {
        merged[row['id'] as String] = row;
      }
      try {
        final rows = merged.values.toList()
          ..sort((a, b) => _dateOf(a).compareTo(_dateOf(b)));
        controller.add(rows);
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    contractSub = contractStream.listen((snapshot) {
      contractRows = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
      emit();
    }, onError: controller.addError);
    legacySub = legacyStream.listen((snapshot) {
      legacyRows = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
      emit();
    }, onError: controller.addError);
    controller.onCancel = () async {
      await contractSub.cancel();
      await legacySub.cancel();
    };
    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> watchUpcomingAppointmentsForMother(
    String motherId,
  ) => watchAppointmentsForMother(motherId).map(
    (rows) => rows
        .where(
          (row) =>
              _dateOf(row).isAfter(DateTime.now()) &&
              {'pending', 'scheduled'}.contains(row['status'] ?? 'scheduled'),
        )
        .toList(),
  );

  Stream<List<Map<String, dynamic>>> watchAppointmentHistory(String motherId) =>
      watchAppointmentsForMother(motherId).map(
        (rows) => rows
            .where(
              (row) => isHistoryAppointment(
                status: (row['status'] ?? 'scheduled').toString(),
                appointmentDate: _dateOf(row),
                now: DateTime.now(),
              ),
            )
            .toList(),
      );

  /// Returns the nearest future pending/scheduled appointment or null.
  Future<Map<String, dynamic>?> getUpcomingAppointment(String motherId) async {
    final rows = await watchAppointmentsForMother(motherId).first;
    final upcoming =
        rows
            .where(
              (row) =>
                  _dateOf(row).isAfter(DateTime.now()) &&
                  {
                    'pending',
                    'scheduled',
                  }.contains(row['status'] ?? 'scheduled'),
            )
            .toList()
          ..sort((a, b) => _dateOf(a).compareTo(_dateOf(b)));
    if (upcoming.isEmpty) return null;
    return upcoming.first;
  }

  static DateTime _dateOf(Map<String, dynamic> data) {
    final value = data['date'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw FormatException('Appointment date is missing or invalid.');
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    final uid = _uid();
    if (await _role(uid) != 'asha') {
      throw StateError('Only an ASHA can update appointment status.');
    }
    final ref = _firestore.collection('appointments').doc(appointmentId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Appointment not found.');
      final data = snapshot.data()!;
      final motherId = data['motherId'] as String? ?? data['userId'] as String?;
      if (motherId == null || motherId.isEmpty) {
        throw StateError('Appointment mother is missing.');
      }
      final mother = await transaction.get(
        _firestore.collection('mothers').doc(motherId),
      );
      if (!mother.exists ||
          !isAssignedAsha(
            authenticatedUid: uid,
            role: 'asha',
            assignedAshaId: mother.data()?['assignedAshaId'] as String?,
          )) {
        throw StateError('Mother is not assigned to this ASHA.');
      }
      final current = (data['status'] ?? 'scheduled').toString();
      validateStatusTransition(current, status);
      transaction.update(ref, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @Deprecated('Appointments are retained; use cancellation status instead.')
  Future<void> deleteAppointment(String appointmentId) async {
    final ref = _firestore.collection('appointments').doc(appointmentId);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw StateError('Appointment not found.');
    if (snapshot.data()?['status'] == 'cancelled') return;
    await updateAppointmentStatus(
      appointmentId: appointmentId,
      status: 'cancelled',
    );
  }
}
