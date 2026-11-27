import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String motherId;
  final DateTime date;
  final String type;
  final String status;
  final bool reminderEnabled;
  final String? doctorName;
  final String? facilityName;
  final String? appointmentKey;

  const AppointmentModel({
    required this.id,
    required this.motherId,
    required this.date,
    required this.type,
    required this.status,
    required this.reminderEnabled,
    this.doctorName,
    this.facilityName,
    this.appointmentKey,
  });

  factory AppointmentModel.fromMap(String id, Map<String, dynamic> data) {
    final dateValue = data['date'];
    final date = dateValue is Timestamp
        ? dateValue.toDate()
        : dateValue is DateTime
        ? dateValue
        : null;
    final motherId = data['motherId'] ?? data['userId'];
    const types = {'routine', 'followUp', 'emergency'};
    const statuses = {'pending', 'scheduled', 'completed', 'cancelled'};
    final type = (data['type'] ?? 'routine').toString();
    final status = (data['status'] ?? 'scheduled').toString();
    if (id.trim().isEmpty || motherId is! String || motherId.trim().isEmpty) {
      throw FormatException('Appointment ID or mother ID is missing.');
    }
    if (date == null) {
      throw FormatException('Appointment date is missing or invalid.');
    }
    if (!types.contains(type)) {
      throw FormatException('Appointment type is invalid.');
    }
    if (!statuses.contains(status)) {
      throw FormatException('Appointment status is invalid.');
    }
    final reminderEnabled = data['reminderEnabled'] ?? false;
    if (reminderEnabled is! bool) {
      throw FormatException('Appointment reminderEnabled must be a boolean.');
    }
    final doctorName = data['doctorName'];
    final facilityName = data['facilityName'];
    final appointmentKey = data['appointmentKey'];
    if ((doctorName != null && doctorName is! String) ||
        (facilityName != null && facilityName is! String) ||
        (appointmentKey != null && appointmentKey is! String)) {
      throw FormatException(
        'Appointment doctor or facility detail is invalid.',
      );
    }
    return AppointmentModel(
      id: id,
      motherId: motherId,
      date: date,
      type: type,
      status: status,
      reminderEnabled: reminderEnabled,
      doctorName: doctorName as String?,
      facilityName: facilityName as String?,
      appointmentKey: appointmentKey as String?,
    );
  }
}
