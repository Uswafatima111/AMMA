import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineReminderModel {
  final String id;
  final String motherId;
  final String medicineName;
  final String instructions;
  final DateTime startDate;
  final DateTime endDate;
  final String reminderTime;
  final bool active;
  final DateTime? createdAt;

  const MedicineReminderModel({
    required this.id,
    required this.motherId,
    required this.medicineName,
    required this.instructions,
    required this.startDate,
    required this.endDate,
    required this.reminderTime,
    required this.active,
    this.createdAt,
  });

  factory MedicineReminderModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? date(Object? value) => value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : null;
    final start = date(data['startDate']);
    final end = date(data['endDate']);
    final created = date(data['createdAt']);
    final motherId = data['motherId'];
    final medicineName = data['medicineName'];
    final instructions = data['instructions'];
    final reminderTime = data['reminderTime'];
    final active = data['active'];
    if (id.isEmpty ||
        motherId is! String ||
        motherId.isEmpty ||
        medicineName is! String ||
        medicineName.trim().isEmpty ||
        instructions is! String ||
        instructions.trim().isEmpty ||
        start == null ||
        end == null ||
        created == null ||
        reminderTime is! String ||
        !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(reminderTime) ||
        active is! bool) {
      throw FormatException(
        'Medicine reminder record is missing valid required fields.',
      );
    }
    if (DateTime.utc(
      start.year,
      start.month,
      start.day,
    ).isAfter(DateTime.utc(end.year, end.month, end.day))) {
      throw FormatException('Medicine reminder end date precedes start date.');
    }
    return MedicineReminderModel(
      id: id,
      motherId: motherId,
      medicineName: medicineName,
      instructions: instructions,
      startDate: start,
      endDate: end,
      reminderTime: reminderTime,
      active: active,
      createdAt: created,
    );
  }
}
