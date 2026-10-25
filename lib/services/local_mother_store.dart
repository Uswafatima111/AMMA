import '../models/mother_model.dart';
import '../core/constants/app_enums.dart';

/// TEMPORARY in-memory store for registered mothers while Firebase isn't
/// running locally. Not persisted across app restarts — once Firebase is
/// confirmed working again, replace reads/writes here with the real
/// Firestore-backed versions.
class LocalMotherStore {
  LocalMotherStore._internal();
  static final LocalMotherStore instance = LocalMotherStore._internal();

  final List<MotherModel> _mothers = [
    MotherModel(
      id: '1',
      name: 'Amina',
      age: 24,
      phone: '9876543210',
      gestationalWeeks: 28,
      bloodPressure: '120/80',
      weight: 58,
      hemoglobin: 11.2,
      symptoms: const [],
      emergencyContact: '9876543211',
      riskLevel: RiskLevel.low,
      assignedAshaId: 'asha1',
      createdAt: DateTime.now(),
    ),
    MotherModel(
      id: '2',
      name: 'Priya',
      age: 27,
      phone: '9876543212',
      gestationalWeeks: 32,
      bloodPressure: '130/85',
      weight: 62,
      hemoglobin: 10.5,
      symptoms: const [],
      emergencyContact: '9876543213',
      riskLevel: RiskLevel.moderate,
      assignedAshaId: 'asha1',
      createdAt: DateTime.now(),
    ),
    MotherModel(
      id: '3',
      name: 'Fatima',
      age: 22,
      phone: '9876543214',
      gestationalWeeks: 36,
      bloodPressure: '140/90',
      weight: 65,
      hemoglobin: 9.8,
      symptoms: const [],
      emergencyContact: '9876543215',
      riskLevel: RiskLevel.high,
      assignedAshaId: 'asha1',
      createdAt: DateTime.now(),
    ),
  ];

  List<MotherModel> get mothers => List.unmodifiable(_mothers);

  void addMother(MotherModel mother) {
    _mothers.add(mother);
  }
}