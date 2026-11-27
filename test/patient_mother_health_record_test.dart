import 'package:flutter_test/flutter_test.dart';
import 'package:amma/services/firestore_service.dart';
import 'package:amma/services/health_record_service.dart';

void main() {
  group('Patient to mother identity', () {
    test('resolves the stable mother document ID from patientUid', () {
      expect(
        FirestoreService.resolvePatientMotherId(
          patientUid: 'patient-1',
          mothers: [
            {'id': 'mother-doc-7', 'patientUid': 'patient-1'},
          ],
        ),
        'mother-doc-7',
      );
    });

    test('returns null when the patient has no link', () {
      expect(
        FirestoreService.resolvePatientMotherId(
          patientUid: 'patient-1',
          mothers: const [],
        ),
        isNull,
      );
    });

    test('rejects duplicate and malformed patient links', () {
      expect(
        () => FirestoreService.resolvePatientMotherId(
          patientUid: 'patient-1',
          mothers: [
            {'id': 'mother-1', 'patientUid': 'patient-1'},
            {'id': 'mother-2', 'patientUid': 'patient-1'},
          ],
        ),
        throwsStateError,
      );
      expect(
        () => FirestoreService.resolvePatientMotherId(
          patientUid: 'patient-1',
          mothers: [
            {'patientUid': 'patient-1'},
          ],
        ),
        throwsStateError,
      );
    });

    test('resolves a legacy ASHA identifier only inside assigned mothers', () {
      final assigned = [
        {'id': 'mother-doc-7', 'patientUid': 'patient-1', 'userId': 'legacy-1'},
      ];
      expect(
        FirestoreService.resolveAssignedMotherId(
          legacyUserId: 'legacy-1',
          mothers: assigned,
        ),
        'mother-doc-7',
      );
      expect(
        FirestoreService.resolveAssignedMotherId(
          legacyUserId: 'other-patient',
          mothers: assigned,
        ),
        isNull,
      );
    });
  });

  group('Health record access', () {
    test('patient ownership is based on authenticated UID', () {
      expect(
        HealthRecordService.canAccessMother(
          authenticatedUid: 'patient-1',
          role: 'patient',
          motherId: 'mother-doc-7',
          patientUid: 'patient-1',
          assignedAshaId: 'asha-1',
        ),
        isTrue,
      );
      expect(
        HealthRecordService.canAccessMother(
          authenticatedUid: 'patient-2',
          role: 'patient',
          motherId: 'mother-doc-7',
          patientUid: 'patient-1',
          assignedAshaId: 'asha-1',
        ),
        isFalse,
      );
    });

    test('only the currently assigned ASHA passes ownership checks', () {
      expect(
        HealthRecordService.canAccessMother(
          authenticatedUid: 'asha-1',
          role: 'asha',
          motherId: 'mother-doc-7',
          patientUid: 'patient-1',
          assignedAshaId: 'asha-1',
        ),
        isTrue,
      );
      expect(
        HealthRecordService.canAccessMother(
          authenticatedUid: 'asha-2',
          role: 'asha',
          motherId: 'mother-doc-7',
          patientUid: 'patient-1',
          assignedAshaId: 'asha-1',
        ),
        isFalse,
      );
      expect(
        HealthRecordService.canAccessMother(
          authenticatedUid: 'patient-1',
          role: 'patient',
          motherId: 'mother-doc-7',
          patientUid: 'patient-1',
          assignedAshaId: 'asha-1',
        ),
        isTrue,
      );
    });

    test('validates inputs before a record can be created', () {
      expect(
        () => HealthRecordService.validateRecord(
          motherId: 'mother-doc-7',
          bloodPressure: '120/80',
          weight: 60,
          hemoglobin: 12,
        ),
        returnsNormally,
      );
      expect(
        () => HealthRecordService.validateRecord(
          motherId: '',
          bloodPressure: '120/80',
          weight: 60,
          hemoglobin: 12,
        ),
        throwsArgumentError,
      );
      expect(
        () => HealthRecordService.validateRecord(
          motherId: 'mother-doc-7',
          bloodPressure: '120/80',
          weight: double.nan,
          hemoglobin: 12,
        ),
        throwsArgumentError,
      );
    });
  });
}
