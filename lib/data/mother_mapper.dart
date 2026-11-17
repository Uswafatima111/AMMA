import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';
import '../models/mother_model.dart';

class MotherMapper {
  static MotherModel fromMap(Map<String, dynamic> data, {String? id}) {
    int toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    double toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

    final created = data['createdAt'];
    final rawSymptoms = data['symptoms'];

    return MotherModel(
      id: id ?? (data['id'] ?? '').toString(),
      name: (data['name'] ?? 'Unknown').toString(),
      age: toInt(data['age']),
      phone: (data['phone'] ?? '').toString(),
      gestationalWeeks:
          toInt(data['gestationalWeeks'] ?? data['pregnancyWeek']),
      bloodPressure: (data['bloodPressure'] ?? '—').toString(),
      weight: toDouble(data['weight']),
      hemoglobin: toDouble(data['hemoglobin']),
      symptoms: rawSymptoms is List
          ? rawSymptoms.map((e) => e.toString()).toList()
          : <String>[],
      emergencyContact: (data['emergencyContact'] ?? '').toString(),
      riskLevel: riskFrom(data['riskLevel']),
      assignedAshaId: (data['assignedAshaId'] ?? '').toString(),
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
    );
  }

  static RiskLevel riskFrom(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'high':
        return RiskLevel.high;
      case 'moderate':
        return RiskLevel.moderate;
      default:
        return RiskLevel.low;
    }
  }
}