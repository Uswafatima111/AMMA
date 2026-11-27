import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';

class ReferralModel {
  final String id;
  final String motherId;
  final String referringAshaId;
  final String facility;
  final ReferralStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  const ReferralModel({
    required this.id,
    required this.motherId,
    required this.referringAshaId,
    required this.facility,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
  });

  factory ReferralModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? date(String key, {bool required = false}) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value == null && !required) return null;
      throw FormatException('Referral timestamp "$key" is missing or invalid.');
    }

    String requiredString(String key) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value;
      throw FormatException('Referral field "$key" is missing or invalid.');
    }

    final statusName = data['status'];
    final status = ReferralStatus.values
        .where((v) => v.name == statusName)
        .firstOrNull;
    if (status == null) {
      throw FormatException('Invalid referral status: $statusName');
    }
    if (id.trim().isEmpty) {
      throw FormatException('Referral document ID is missing.');
    }
    return ReferralModel(
      id: id,
      motherId: requiredString('motherId'),
      referringAshaId: requiredString('referringAshaId'),
      facility: requiredString('facility'),
      status: status,
      createdAt: date('createdAt', required: true)!,
      updatedAt: date('updatedAt'),
      acceptedAt: date('acceptedAt'),
      completedAt: date('completedAt'),
      cancelledAt: date('cancelledAt'),
    );
  }
}
