import 'package:flutter_test/flutter_test.dart';
import 'package:amma/core/constants/app_enums.dart';
import 'package:amma/services/emergency_service.dart';
import 'package:amma/services/referral_service.dart';
import 'package:amma/models/referral_model.dart';

void main() {
  group('Emergency lifecycle', () {
    test('accepts only active -> responded -> resolved', () {
      expect(EmergencyService.canTransition('active', 'responded'), isTrue);
      expect(EmergencyService.canTransition('responded', 'resolved'), isTrue);
      expect(EmergencyService.canTransition('active', 'resolved'), isFalse);
      expect(EmergencyService.canTransition('resolved', 'active'), isFalse);
    });

    test('rejects invalid status transitions', () {
      expect(
        () => EmergencyService.validateTransition('active', 'resolved'),
        throwsStateError,
      );
    });

    test('validates patient ownership', () {
      expect(
        () => EmergencyService.validateTransition('unknown', 'responded'),
        throwsStateError,
      );
      expect(
        EmergencyService.patientOwnsRequest(
          authenticatedUid: 'patient-a',
          patientId: 'patient-a',
        ),
        isTrue,
      );
      expect(
        EmergencyService.patientOwnsRequest(
          authenticatedUid: 'patient-a',
          patientId: 'patient-b',
        ),
        isFalse,
      );
      expect(
        EmergencyService.patientOwnsRequest(
          authenticatedUid: '',
          patientId: '',
        ),
        isFalse,
      );
    });

    test('missing or unassigned ASHA cannot perform assigned actions', () {
      expect(
        EmergencyService.isAssignedAsha(
          authenticatedUid: 'asha-a',
          role: 'asha',
          assignedAshaId: 'asha-a',
          motherAssignedAshaId: 'asha-a',
        ),
        isTrue,
      );
      expect(
        EmergencyService.isAssignedAsha(
          authenticatedUid: 'asha-a',
          role: 'asha',
          assignedAshaId: null,
          motherAssignedAshaId: null,
        ),
        isFalse,
      );
      expect(
        EmergencyService.isAssignedAsha(
          authenticatedUid: 'asha-a',
          role: 'patient',
          assignedAshaId: 'asha-a',
          motherAssignedAshaId: 'asha-a',
        ),
        isFalse,
      );
      expect(
        EmergencyService.isAssignedAsha(
          authenticatedUid: 'asha-a',
          role: 'asha',
          assignedAshaId: 'asha-a',
          motherAssignedAshaId: 'asha-b',
        ),
        isFalse,
      );
    });

    test('access follows current ASHA assignment after reassignment', () {
      expect(
        EmergencyService.isAssignedAsha(
          authenticatedUid: 'asha-original',
          role: 'asha',
          assignedAshaId: 'asha-original',
          motherAssignedAshaId: 'asha-current',
        ),
        isFalse,
      );
      expect(
        EmergencyService.isAssignedAsha(
          authenticatedUid: 'asha-current',
          role: 'asha',
          assignedAshaId: 'asha-original',
          motherAssignedAshaId: 'asha-current',
        ),
        isTrue,
      );
      expect(
        EmergencyService.isAssignedAsha(
          authenticatedUid: 'asha-unrelated',
          role: 'asha',
          assignedAshaId: 'asha-original',
          motherAssignedAshaId: 'asha-current',
        ),
        isFalse,
      );
    });

    test('newly assigned ASHA may advance active and responded requests', () {
      expect(
        EmergencyService.isAssignedAsha(
          authenticatedUid: 'asha-current',
          role: 'asha',
          assignedAshaId: 'asha-original',
          motherAssignedAshaId: 'asha-current',
        ),
        isTrue,
      );
      expect(EmergencyService.canTransition('active', 'responded'), isTrue);
      expect(EmergencyService.canTransition('responded', 'resolved'), isTrue);
    });

    test('patient retains ownership access after ASHA reassignment', () {
      expect(
        EmergencyService.patientOwnsRequest(
          authenticatedUid: 'patient-1',
          patientId: 'patient-1',
        ),
        isTrue,
      );
    });

    test(
      'a linked mother cannot be omitted, while no link permits unassigned request',
      () {
        expect(
          EmergencyService.hasValidMotherAssignment(
            hasLinkedMother: true,
            motherId: null,
            assignedAshaId: null,
          ),
          isFalse,
        );
        expect(
          EmergencyService.hasValidMotherAssignment(
            hasLinkedMother: true,
            motherId: 'mother-1',
            assignedAshaId: 'asha-1',
          ),
          isTrue,
        );
        expect(
          EmergencyService.hasValidMotherAssignment(
            hasLinkedMother: false,
            motherId: null,
            assignedAshaId: null,
          ),
          isTrue,
        );
        expect(
          EmergencyService.hasValidMotherAssignment(
            hasLinkedMother: false,
            motherId: 'mother-1',
            assignedAshaId: 'asha-1',
          ),
          isFalse,
        );
      },
    );

    test('resolution update leaves original responder metadata untouched', () {
      final update = EmergencyService.resolutionUpdate('asha-current');
      expect(update.keys, containsAll(['status', 'resolvedAt', 'resolvedBy']));
      expect(update.keys, isNot(contains('respondedAt')));
      expect(update.keys, isNot(contains('respondedBy')));
      expect(EmergencyService.canTransition('responded', 'resolved'), isTrue);
      expect(EmergencyService.canTransition('active', 'resolved'), isFalse);
    });
  });

  group('Referral lifecycle', () {
    test(
      'allows pending -> accepted/cancelled and accepted -> completed/cancelled',
      () {
        expect(
          ReferralService.canTransition(
            ReferralStatus.pending,
            ReferralStatus.accepted,
          ),
          isTrue,
        );
        expect(
          ReferralService.canTransition(
            ReferralStatus.pending,
            ReferralStatus.cancelled,
          ),
          isTrue,
        );
        expect(
          ReferralService.canTransition(
            ReferralStatus.accepted,
            ReferralStatus.completed,
          ),
          isTrue,
        );
        expect(
          ReferralService.canTransition(
            ReferralStatus.accepted,
            ReferralStatus.cancelled,
          ),
          isTrue,
        );
      },
    );

    test('rejects terminal and backwards transitions', () {
      expect(
        () => ReferralService.validateTransition(
          ReferralStatus.completed,
          ReferralStatus.pending,
        ),
        throwsStateError,
      );
      expect(
        () => ReferralService.validateTransition(
          ReferralStatus.cancelled,
          ReferralStatus.accepted,
        ),
        throwsStateError,
      );
    });

    test('reassigned ASHA can access referral; unrelated ASHA cannot', () {
      expect(
        ReferralService.canAccessReferral(
          authenticatedUid: 'asha-new',
          role: 'asha',
          motherAssignedAshaId: 'asha-new',
        ),
        isTrue,
      );
      expect(
        ReferralService.canAccessReferral(
          authenticatedUid: 'asha-other',
          role: 'asha',
          motherAssignedAshaId: 'asha-new',
        ),
        isFalse,
      );
      expect(
        ReferralService.canAccessReferral(
          authenticatedUid: 'patient-1',
          role: 'patient',
          motherAssignedAshaId: 'patient-1',
        ),
        isFalse,
      );
    });

    test(
      'missing or malformed required timestamps fail parsing explicitly',
      () {
        final data = <String, dynamic>{
          'motherId': 'mother-1',
          'referringAshaId': 'asha-1',
          'facility': 'Clinic',
          'status': 'pending',
        };
        expect(
          () => ReferralModel.fromMap('ref-1', data),
          throwsFormatException,
        );
        expect(
          () => ReferralModel.fromMap('ref-1', {
            ...data,
            'createdAt': 'not-a-date',
          }),
          throwsFormatException,
        );
        expect(
          () => ReferralModel.fromMap('ref-1', {
            ...data,
            'createdAt': DateTime.utc(2026),
            'updatedAt': 42,
          }),
          throwsFormatException,
        );
      },
    );
  });
}
