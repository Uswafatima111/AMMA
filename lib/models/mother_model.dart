import '../core/constants/app_enums.dart';

class MotherModel {
  final String id;
  final String name;
  final int age;
  final String phone;
  final int gestationalWeeks;
  final String bloodPressure;
  final double weight;
  final double hemoglobin;
  final List<String> symptoms;
  final String emergencyContact;
  final RiskLevel riskLevel;
  final String assignedAshaId;
  final DateTime createdAt;

  const MotherModel({
    required this.id,
    required this.name,
    required this.age,
    required this.phone,
    required this.gestationalWeeks,
    required this.bloodPressure,
    required this.weight,
    required this.hemoglobin,
    required this.symptoms,
    required this.emergencyContact,
    required this.riskLevel,
    required this.assignedAshaId,
    required this.createdAt,
  });
}