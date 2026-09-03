import '../core/constants/app_enums.dart';

class AlertModel {
  final String id;
  final String motherId;
  final String type;
  final RiskLevel riskLevel;
  final String message;
  final String status;
  final DateTime createdAt;

  const AlertModel({
    required this.id,
    required this.motherId,
    required this.type,
    required this.riskLevel,
    required this.message,
    required this.status,
    required this.createdAt,
  });
}