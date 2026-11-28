import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';

import {
  authenticatedContext,
  seedDocuments,
  unauthenticatedContext,
} from './contexts.js';

const projectId = 'demo-amma-rules';
const patientUid = 'patient-one';
const otherPatientUid = 'patient-two';
const assignedAshaUid = 'asha-one';
const otherAshaUid = 'asha-two';
const motherId = 'mother-one';
const otherMotherId = 'mother-two';
const recordId = 'record-one';
const emergencyId = 'emergency-one';
const referralId = 'referral-one';
const appointmentId = 'appointment-one';

let environment;
const Timestamp = firebase.firestore.Timestamp;
const serverTimestamp = () => firebase.firestore.FieldValue.serverTimestamp();

// RulesTestContext.firestore() returns the Firebase compat Firestore client.
function doc(db, path) {
  return db.doc(path);
}

function getDoc(reference) {
  return reference.get();
}

function setDoc(reference, data) {
  return reference.set(data);
}

function updateDoc(reference, data) {
  return reference.update(data);
}

function deleteDoc(reference) {
  return reference.delete();
}

function profile(role) {
  return { id: role === 'patient' ? patientUid : assignedAshaUid, role };
}

function mother(patient = patientUid, asha = assignedAshaUid) {
  return {
    id: motherId,
    patientUid: patient,
    assignedAshaId: asha,
    name: 'Test Mother',
  };
}

function healthRecord(id = recordId, linkedMotherId = motherId) {
  return {
    id,
    motherId: linkedMotherId,
    bloodPressure: '110/70',
    weight: 60,
    hemoglobin: 11,
    symptoms: [],
    date: Timestamp.fromMillis(Date.now()),
    recordedAt: Timestamp.fromMillis(Date.now()),
    notes: '',
    createdBy: assignedAshaUid,
  };
}

async function seedBase() {
  await seedDocuments(environment, {
    [`users/${patientUid}`]: {
      ...profile('patient'),
      id: patientUid,
      assignedMotherId: motherId,
    },
    [`users/${otherPatientUid}`]: { id: otherPatientUid, role: 'patient' },
    [`users/${assignedAshaUid}`]: {
      ...profile('asha'),
      id: assignedAshaUid,
      name: 'Assigned ASHA',
      email: 'assigned@example.test',
      phone: '1111111111',
    },
    [`users/${otherAshaUid}`]: {
      id: otherAshaUid,
      role: 'asha',
      name: 'Other ASHA',
      email: 'other@example.test',
      phone: '2222222222',
    },
    [`asha_contacts/${assignedAshaUid}`]: {
      id: assignedAshaUid,
      name: 'Assigned ASHA',
      phone: '1111111111',
    },
    [`asha_contacts/${otherAshaUid}`]: {
      id: otherAshaUid,
      name: 'Other ASHA',
      phone: '2222222222',
    },
    [`mothers/${motherId}`]: mother(),
    [`mothers/${otherMotherId}`]: {
      id: otherMotherId,
      patientUid: otherPatientUid,
      assignedAshaId: otherAshaUid,
      name: 'Other Mother',
    },
    [`health_records/${recordId}`]: healthRecord(),
    'health_records/other-record': healthRecord('other-record', otherMotherId),
  });
}

describe('AMMA Firestore security rules', () => {
  before(async () => {
    const rules = await readFile(
      fileURLToPath(new URL('../firestore.rules', import.meta.url)),
      'utf8',
    );
    environment = await initializeTestEnvironment({
      projectId,
      firestore: { rules },
    });
  });

  beforeEach(async () => {
    await environment.clearFirestore();
  });

  after(async () => {
    await environment?.cleanup();
  });

  it('denies unauthenticated reads and writes', async () => {
    await seedBase();
    const db = unauthenticatedContext(environment).firestore();
    await assertFails(getDoc(doc(db, `mothers/${motherId}`)));
    await assertFails(
      setDoc(doc(db, 'users/anonymous'), { id: 'anonymous', role: 'patient' }),
    );
  });

  it('allows a patient to read their own profile and denies another profile', async () => {
    await seedBase();
    const db = authenticatedContext(environment, patientUid).firestore();
    const ownProfile = await assertSucceeds(getDoc(doc(db, `users/${patientUid}`)));
    assert.equal(ownProfile.data().role, 'patient');
    await assertFails(getDoc(doc(db, `users/${otherPatientUid}`)));
  });

  it('denies a patient access to another patient’s health records', async () => {
    await seedBase();
    const db = authenticatedContext(environment, patientUid).firestore();
    await assertSucceeds(getDoc(doc(db, `health_records/${recordId}`)));
    await assertFails(getDoc(doc(db, 'health_records/other-record')));
  });

  it('requires canonical health records to match the patient linked to their mother', async () => {
    await seedBase();
    await seedDocuments(environment, {
      'health_records/mismatched-user': {
        ...healthRecord('mismatched-user'),
        userId: otherPatientUid,
      },
    });

    const ownerDb = authenticatedContext(environment, patientUid).firestore();
    const unrelatedPatientDb = authenticatedContext(environment, otherPatientUid).firestore();
    const assignedAshaDb = authenticatedContext(environment, assignedAshaUid).firestore();

    // Canonical records without a redundant userId remain readable through
    // the verified patientUid -> motherId relationship.
    await assertSucceeds(getDoc(doc(ownerDb, `health_records/${recordId}`)));
    // A mismatched optional userId invalidates the patient read, while the
    // assigned ASHA retains access through the mother assignment.
    await assertFails(getDoc(doc(ownerDb, 'health_records/mismatched-user')));
    await assertFails(getDoc(doc(unrelatedPatientDb, 'health_records/mismatched-user')));
    await assertSucceeds(getDoc(doc(assignedAshaDb, 'health_records/mismatched-user')));
  });

  it('rejects health-record writes with forged, mismatched, missing, or invalid ownership', async () => {
    await seedBase();
    const ashaDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const record = (id, overrides = {}) => ({
      ...healthRecord(id),
      date: serverTimestamp(),
      recordedAt: serverTimestamp(),
      ...overrides,
    });

    await assertSucceeds(setDoc(doc(ashaDb, 'health_records/valid-user-link'),
      record('valid-user-link', {userId: patientUid})));
    await assertFails(setDoc(doc(ashaDb, 'health_records/forged-user-link'),
      record('forged-user-link', {userId: otherPatientUid})));
    const missingMother = record('missing-mother');
    delete missingMother.motherId;
    await assertFails(setDoc(doc(ashaDb, 'health_records/missing-mother'), missingMother));
    await assertFails(setDoc(doc(ashaDb, 'health_records/invalid-mother'),
      record('invalid-mother', {motherId: 'not-an-assigned-mother'})));
  });

  it('allows only unlinked userId-only legacy health records through the fallback', async () => {
    await seedBase();
    await seedDocuments(environment, {
      'users/legacy-patient': {id: 'legacy-patient', role: 'patient'},
      'health_records/legacy-only-user-id': {
        id: 'legacy-only-user-id',
        userId: 'legacy-patient',
        bloodPressure: '110/70',
        weight: 60,
        hemoglobin: 11,
        symptoms: [],
        recordedAt: Timestamp.fromMillis(Date.now()),
      },
      'health_records/linked-patient-legacy-row': {
        id: 'linked-patient-legacy-row',
        userId: patientUid,
        bloodPressure: '110/70',
        weight: 60,
        hemoglobin: 11,
        symptoms: [],
        recordedAt: Timestamp.fromMillis(Date.now()),
      },
    });

    const legacyPatientDb = authenticatedContext(environment, 'legacy-patient').firestore();
    const linkedPatientDb = authenticatedContext(environment, patientUid).firestore();
    const unrelatedPatientDb = authenticatedContext(environment, otherPatientUid).firestore();

    await assertSucceeds(getDoc(doc(legacyPatientDb, 'health_records/legacy-only-user-id')));
    await assertFails(getDoc(doc(unrelatedPatientDb, 'health_records/legacy-only-user-id')));
    // A linked profile must use the canonical mother-scoped path; a bare
    // userId value cannot bypass its verified link.
    await assertFails(getDoc(doc(linkedPatientDb, 'health_records/linked-patient-legacy-row')));
  });

  it('allows the assigned ASHA to read an assigned mother and her records', async () => {
    await seedBase();
    const db = authenticatedContext(environment, assignedAshaUid).firestore();
    await assertSucceeds(getDoc(doc(db, `mothers/${motherId}`)));
    await assertSucceeds(getDoc(doc(db, `health_records/${recordId}`)));
    await assertSucceeds(getDoc(doc(db, `users/${patientUid}`)));
  });

  it('denies an unassigned ASHA access to a mother and her records', async () => {
    await seedBase();
    const db = authenticatedContext(environment, otherAshaUid).firestore();
    await assertFails(getDoc(doc(db, `mothers/${motherId}`)));
    await assertFails(getDoc(doc(db, `health_records/${recordId}`)));
  });

  it('allows patients to read only their assigned ASHA contact projection', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const contact = await assertSucceeds(
      getDoc(doc(patientDb, `asha_contacts/${assignedAshaUid}`)),
    );
    assert.deepEqual(
      Object.keys(contact.data()).sort(),
      ['id', 'name', 'phone'],
    );
    assert.equal(contact.data().name, 'Assigned ASHA');
    await assertFails(getDoc(doc(patientDb, `asha_contacts/${otherAshaUid}`)));
    await assertFails(getDoc(doc(patientDb, `users/${assignedAshaUid}`)));
    await assertFails(patientDb.collection('asha_contacts').get());

    const otherPatientDb = authenticatedContext(environment, otherPatientUid).firestore();
    await assertFails(
      getDoc(doc(otherPatientDb, `asha_contacts/${assignedAshaUid}`)),
    );
  });

  it('preserves ASHA self and administrator contact access without allowing profile spoofing', async () => {
    await seedBase();
    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    await assertSucceeds(
      getDoc(doc(assignedDb, `asha_contacts/${assignedAshaUid}`)),
    );
    await assertSucceeds(
      setDoc(doc(assignedDb, `asha_contacts/${assignedAshaUid}`), {
        id: assignedAshaUid,
        name: 'Assigned ASHA',
        phone: '1111111111',
      }),
    );
    await assertFails(
      setDoc(doc(assignedDb, `asha_contacts/${otherAshaUid}`), {
        id: otherAshaUid,
        name: 'Other ASHA',
        phone: '2222222222',
      }),
    );
    await assertFails(
      setDoc(doc(assignedDb, `asha_contacts/${assignedAshaUid}`), {
        id: assignedAshaUid,
        name: 'Spoofed Name',
        phone: '9999999999',
      }),
    );

    await environment.withSecurityRulesDisabled(async (context) => {
      const adminContact = await context.firestore()
        .doc(`asha_contacts/${otherAshaUid}`)
        .get();
      assert.equal(adminContact.data().name, 'Other ASHA');
    });
  });

  for (const requestType of ['benefit_help', 'appointment_request']) {
    it(`allows a patient to create and read their own ${requestType} request`, async () => {
      await seedBase();
      const patientDb = authenticatedContext(environment, patientUid).firestore();
      const request = {
        id: `${requestType}-request`,
        userId: patientUid,
        motherId,
        assignedAshaId: assignedAshaUid,
        type: requestType,
        riskLevel: 'low',
        message: 'Please contact me about this request.',
        status: 'open',
        createdAt: serverTimestamp(),
      };
      const requestRef = doc(patientDb, `alerts/${request.id}`);
      await assertSucceeds(setDoc(requestRef, request));
      await assertSucceeds(getDoc(requestRef));

      const ownRequests = await assertSucceeds(
        patientDb.collection('alerts').where('motherId', '==', motherId).get(),
      );
      assert.equal(ownRequests.size, 1);
      await assertFails(
        patientDb.collection('alerts').where('userId', '==', patientUid).get(),
      );

      const otherPatientDb = authenticatedContext(environment, otherPatientUid).firestore();
      await assertFails(getDoc(doc(otherPatientDb, `alerts/${request.id}`)));
      await assertFails(
        otherPatientDb.collection('alerts').where('userId', '==', patientUid).get(),
      );

      const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
      const assignedRequests = await assertSucceeds(
        assignedDb.collection('alerts').where('motherId', '==', motherId).get(),
      );
      assert.equal(assignedRequests.size, 1);
    });
  }

  it('rejects patient help requests with an unsupported type or unrelated assignment', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const baseRequest = {
      id: 'invalid-request',
      userId: patientUid,
      motherId,
      assignedAshaId: assignedAshaUid,
      type: 'benefit_help',
      riskLevel: 'low',
      message: 'Please contact me.',
      status: 'open',
      createdAt: serverTimestamp(),
    };

    await assertFails(
      setDoc(doc(patientDb, 'alerts/unsupported-type'), {
        ...baseRequest,
        id: 'unsupported-type',
        type: 'medical_emergency',
      }),
    );
    await assertFails(
      setDoc(doc(patientDb, 'alerts/unrelated-mother'), {
        ...baseRequest,
        id: 'unrelated-mother',
        motherId: otherMotherId,
        assignedAshaId: otherAshaUid,
      }),
    );
    await assertFails(
      setDoc(doc(patientDb, 'alerts/wrong-asha'), {
        ...baseRequest,
        id: 'wrong-asha',
        assignedAshaId: otherAshaUid,
      }),
    );
  });

  it('preserves assigned ASHA alert creation and patient access to own-mother alerts', async () => {
    await seedBase();
    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const alert = {
      id: 'asha-alert-one',
      motherId,
      userId: patientUid,
      type: 'nearing_delivery',
      riskLevel: 'moderate',
      message: 'Follow up with the mother.',
      status: 'open',
      createdAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(assignedDb, 'alerts/asha-alert-one'), alert));

    const patientDb = authenticatedContext(environment, patientUid).firestore();
    await assertSucceeds(getDoc(doc(patientDb, 'alerts/asha-alert-one')));
    const ownMotherAlerts = await assertSucceeds(
      patientDb.collection('alerts').where('motherId', '==', motherId).get(),
    );
    assert.equal(ownMotherAlerts.size, 1);
  });

  it('rejects forged or mother-mismatched userId values on ASHA alerts', async () => {
    await seedBase();
    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const forged = {
      id: 'forged-user-alert',
      motherId,
      userId: otherPatientUid,
      type: 'nearing_delivery',
      riskLevel: 'moderate',
      message: 'This must remain private to the linked mother.',
      status: 'open',
      createdAt: serverTimestamp(),
    };
    await assertFails(setDoc(doc(assignedDb, 'alerts/forged-user-alert'), forged));

    const mismatchedMother = {
      ...forged,
      id: 'mismatched-mother-alert',
      motherId: otherMotherId,
      userId: patientUid,
    };
    const otherAssignedDb = authenticatedContext(environment, otherAshaUid).firestore();
    await assertFails(
      setDoc(doc(otherAssignedDb, 'alerts/mismatched-mother-alert'), mismatchedMother),
    );

    await seedDocuments(environment, {
      'alerts/seeded-mismatched-user': {
        ...forged,
        id: 'seeded-mismatched-user',
        createdAt: Timestamp.fromMillis(Date.now()),
      },
    });
    const ownerDb = authenticatedContext(environment, patientUid).firestore();
    const unrelatedPatientDb = authenticatedContext(environment, otherPatientUid).firestore();
    await assertFails(getDoc(doc(ownerDb, 'alerts/seeded-mismatched-user')));
    await assertFails(getDoc(doc(unrelatedPatientDb, 'alerts/seeded-mismatched-user')));
    await assertSucceeds(getDoc(doc(assignedDb, 'alerts/seeded-mismatched-user')));
  });

  it('allows only explicitly shaped legacy alerts for a verified UID-keyed mother', async () => {
    await seedBase();
    await seedDocuments(environment, {
      [`mothers/${patientUid}`]: {
        id: patientUid,
        patientUid,
        assignedAshaId: assignedAshaUid,
        name: 'Legacy UID-keyed mother',
      },
      'alerts/legacy-patient-alert': {
        id: 'legacy-patient-alert',
        userId: patientUid,
        title: 'Legacy follow-up',
        message: 'Please contact your ASHA.',
        type: 'follow_up',
        severity: 'low',
        riskLevel: 'low',
        status: 'open',
        isRead: false,
        createdAt: Timestamp.fromMillis(Date.now()),
      },
      'alerts/legacy-without-mother': {
        id: 'legacy-without-mother',
        userId: otherPatientUid,
        title: 'Unverified legacy alert',
        message: 'This has no verified UID-keyed mother.',
        type: 'follow_up',
        createdAt: Timestamp.fromMillis(Date.now()),
      },
    });

    const ownerDb = authenticatedContext(environment, patientUid).firestore();
    const unrelatedPatientDb = authenticatedContext(environment, otherPatientUid).firestore();
    await assertSucceeds(getDoc(doc(ownerDb, 'alerts/legacy-patient-alert')));
    await assertFails(getDoc(doc(unrelatedPatientDb, 'alerts/legacy-patient-alert')));
    await assertFails(getDoc(doc(unrelatedPatientDb, 'alerts/legacy-without-mother')));
  });

  it('allows only assigned ASHAs to advance help requests through existing statuses', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const request = {
      id: 'request-lifecycle',
      userId: patientUid,
      motherId,
      assignedAshaId: assignedAshaUid,
      type: 'appointment_request',
      riskLevel: 'low',
      message: 'Please help schedule a visit.',
      status: 'open',
      createdAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(patientDb, 'alerts/request-lifecycle'), request));

    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const requestRef = doc(assignedDb, 'alerts/request-lifecycle');
    for (const status of ['read', 'pending', 'accepted', 'completed']) {
      await assertSucceeds(updateDoc(requestRef, { status }));
    }
    const completed = await assertSucceeds(getDoc(requestRef));
    assert.equal(completed.data().status, 'completed');
    assert.equal(completed.data().userId, patientUid);
    assert.equal(completed.data().motherId, motherId);
    assert.equal(completed.data().assignedAshaId, assignedAshaUid);
    assert.equal(completed.data().type, request.type);
  });

  it('follows the current mother assignment without changing the recorded ASHA field', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const request = {
      id: 'request-reassigned',
      userId: patientUid,
      motherId,
      assignedAshaId: assignedAshaUid,
      type: 'benefit_help',
      riskLevel: 'low',
      message: 'Please help.',
      status: 'open',
      createdAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(patientDb, 'alerts/request-reassigned'), request));
    await seedDocuments(environment, {
      [`mothers/${motherId}`]: {
        ...mother(),
        assignedAshaId: otherAshaUid,
      },
    });

    const oldAshaDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const newAshaDb = authenticatedContext(environment, otherAshaUid).firestore();
    await assertFails(
      updateDoc(doc(oldAshaDb, 'alerts/request-reassigned'), { status: 'read' }),
    );
    await assertSucceeds(
      updateDoc(doc(newAshaDb, 'alerts/request-reassigned'), { status: 'read' }),
    );
    const updated = await assertSucceeds(
      getDoc(doc(newAshaDb, 'alerts/request-reassigned')),
    );
    assert.equal(updated.data().assignedAshaId, assignedAshaUid);
    assert.equal(updated.data().status, 'read');
  });

  it('denies invalid help-request transitions and changes to immutable fields', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const request = {
      id: 'request-immutable',
      userId: patientUid,
      motherId,
      assignedAshaId: assignedAshaUid,
      type: 'benefit_help',
      riskLevel: 'low',
      message: 'Please help.',
      status: 'open',
      createdAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(patientDb, 'alerts/request-immutable'), request));
    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const requestRef = doc(assignedDb, 'alerts/request-immutable');

    await assertFails(updateDoc(requestRef, { status: 'completed' }));
    await assertFails(updateDoc(requestRef, { status: 'read', message: 'changed' }));
    await assertFails(updateDoc(requestRef, { status: 'read', userId: otherPatientUid }));
    await assertFails(updateDoc(requestRef, { status: 'read', motherId: otherMotherId }));
    await assertFails(
      updateDoc(requestRef, { status: 'read', assignedAshaId: otherAshaUid }),
    );
    await assertFails(updateDoc(requestRef, { status: 'read', type: 'nearing_delivery' }));
    await assertFails(updateDoc(requestRef, { status: 'read', createdAt: serverTimestamp() }));

    const unchanged = await assertSucceeds(getDoc(requestRef));
    assert.equal(unchanged.data().status, 'open');
  });

  it('denies patients and unrelated ASHAs from updating help requests', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const request = {
      id: 'request-authorization',
      userId: patientUid,
      motherId,
      assignedAshaId: assignedAshaUid,
      type: 'benefit_help',
      riskLevel: 'low',
      message: 'Please help.',
      status: 'open',
      createdAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(patientDb, 'alerts/request-authorization'), request));
    const requestPath = 'alerts/request-authorization';
    await assertFails(updateDoc(doc(patientDb, requestPath), { status: 'read' }));

    const unrelatedDb = authenticatedContext(environment, otherAshaUid).firestore();
    await assertFails(updateDoc(doc(unrelatedDb, requestPath), { status: 'read' }));

    const otherPatientDb = authenticatedContext(environment, otherPatientUid).firestore();
    await assertFails(updateDoc(doc(otherPatientDb, requestPath), { status: 'read' }));

    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const unchanged = await assertSucceeds(
      getDoc(doc(assignedDb, requestPath)),
    );
    assert.equal(unchanged.data().status, 'open');
  });

  it('does not let a patient create or update a profile to the ASHA role', async () => {
    await seedBase();
    const db = authenticatedContext(environment, patientUid).firestore();
    const newPatientDb = authenticatedContext(environment, 'new-self').firestore();
    await assertFails(
      setDoc(doc(newPatientDb, 'users/new-self'), { id: 'new-self', role: 'asha' }),
    );
    await assertFails(
      updateDoc(doc(db, `users/${patientUid}`), { role: 'asha' }),
    );
  });

  it('keeps health records immutable to clients', async () => {
    await seedBase();
    const db = authenticatedContext(environment, assignedAshaUid).firestore();
    await assertFails(
      updateDoc(doc(db, `health_records/${recordId}`), { notes: 'edited' }),
    );
    await assertFails(deleteDoc(doc(db, `health_records/${recordId}`)));
  });

  it('authorizes emergency creation and reads only for the patient and assigned ASHA', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const request = {
      patientId: patientUid,
      motherId,
      assignedAshaId: assignedAshaUid,
      message: 'Please help',
      type: 'medical_emergency',
      severity: 'critical',
      status: 'active',
      latitude: null,
      longitude: null,
      createdAt: serverTimestamp(),
      respondedAt: null,
      respondedBy: null,
      resolvedAt: null,
      resolvedBy: null,
    };
    await assertSucceeds(setDoc(doc(patientDb, `emergency_requests/${emergencyId}`), request));
    await assertFails(
      setDoc(doc(patientDb, 'emergency_requests/for-other-patient'), {
        ...request,
        patientId: otherPatientUid,
      }),
    );

    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const unrelatedDb = authenticatedContext(environment, otherAshaUid).firestore();
    await assertSucceeds(getDoc(doc(assignedDb, `emergency_requests/${emergencyId}`)));
    await assertFails(getDoc(doc(unrelatedDb, `emergency_requests/${emergencyId}`)));
  });

  it('enforces emergency ownership, assigned ASHA transitions, and immutable identity', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const request = {
      patientId: patientUid,
      motherId,
      assignedAshaId: assignedAshaUid,
      message: 'Please help',
      type: 'medical_emergency',
      severity: 'critical',
      status: 'active',
      latitude: null,
      longitude: null,
      createdAt: serverTimestamp(),
      respondedAt: null,
      respondedBy: null,
      resolvedAt: null,
      resolvedBy: null,
    };
    const requestRef = doc(patientDb, 'emergency_requests/emergency-lifecycle');
    await assertSucceeds(setDoc(requestRef, request));
    await assertFails(setDoc(
      doc(patientDb, 'emergency_requests/wrong-mother'),
      {...request, motherId: otherMotherId},
    ));
    await assertFails(setDoc(
      doc(patientDb, 'emergency_requests/wrong-assignment'),
      {...request, assignedAshaId: otherAshaUid},
    ));
    await assertFails(setDoc(
      doc(patientDb, 'emergency_requests/linked-patient-orphan'),
      {...request, motherId: null, assignedAshaId: null},
    ));
    await assertFails(updateDoc(doc(patientDb, `users/${patientUid}`), {
      assignedMotherId: firebase.firestore.FieldValue.delete(),
    }));
    await seedDocuments(environment, {
      'users/legacy-patient': {id: 'legacy-patient', role: 'patient'},
      'mothers/legacy-patient': {
        id: 'legacy-patient',
        userId: 'legacy-patient',
        patientUid: otherPatientUid,
        assignedAshaId: assignedAshaUid,
      },
    });
    const conflictingLegacyDb = authenticatedContext(environment, 'legacy-patient').firestore();
    await assertFails(setDoc(
      doc(conflictingLegacyDb, 'emergency_requests/conflicting-legacy-mother'),
      {...request, patientId: 'legacy-patient', motherId: 'legacy-patient'},
    ));

    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const unrelatedDb = authenticatedContext(environment, otherAshaUid).firestore();
    const assignedRef = doc(assignedDb, 'emergency_requests/emergency-lifecycle');
    await assertFails(updateDoc(requestRef, {status: 'responded'}));
    await assertFails(updateDoc(
      doc(unrelatedDb, 'emergency_requests/emergency-lifecycle'),
      {status: 'responded'},
    ));
    await assertFails(updateDoc(assignedRef, {status: 'resolved'}));
    await assertFails(updateDoc(assignedRef, {
      status: 'responded',
      patientId: otherPatientUid,
      respondedAt: serverTimestamp(),
      respondedBy: assignedAshaUid,
    }));

    await assertSucceeds(updateDoc(assignedRef, {
      status: 'responded',
      respondedAt: serverTimestamp(),
      respondedBy: assignedAshaUid,
    }));
    const response = await assertSucceeds(getDoc(assignedRef));
    await assertSucceeds(updateDoc(assignedRef, {
      status: 'resolved',
      respondedAt: response.data().respondedAt,
      respondedBy: response.data().respondedBy,
      resolvedAt: serverTimestamp(),
      resolvedBy: assignedAshaUid,
    }));
    await assertFails(updateDoc(assignedRef, {status: 'active'}));

    const resolved = await assertSucceeds(getDoc(assignedRef));
    assert.equal(resolved.data().patientId, patientUid);
    assert.equal(resolved.data().motherId, motherId);
    assert.equal(resolved.data().assignedAshaId, assignedAshaUid);
    assert.equal(resolved.data().respondedBy, assignedAshaUid);
    assert.equal(resolved.data().resolvedBy, assignedAshaUid);
  });

  it('retains unassigned emergency requests for patients with no linked mother', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, otherPatientUid).firestore();
    const request = {
      patientId: otherPatientUid,
      motherId: null,
      assignedAshaId: null,
      message: 'Please help.',
      type: 'medical_emergency',
      severity: 'critical',
      status: 'active',
      latitude: null,
      longitude: null,
      createdAt: serverTimestamp(),
      respondedAt: null,
      respondedBy: null,
      resolvedAt: null,
      resolvedBy: null,
    };
    await assertSucceeds(setDoc(
      doc(patientDb, 'emergency_requests/unassigned-patient-request'),
      request,
    ));
  });

  it('authorizes referrals only for the ASHA assigned to the mother', async () => {
    await seedBase();
    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const unrelatedDb = authenticatedContext(environment, otherAshaUid).firestore();
    const referral = {
      motherId,
      referringAshaId: assignedAshaUid,
      facility: 'Community Health Center',
      status: 'pending',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      acceptedAt: null,
      completedAt: null,
      cancelledAt: null,
    };
    await assertSucceeds(setDoc(doc(assignedDb, `referrals/${referralId}`), referral));
    await assertSucceeds(getDoc(doc(assignedDb, `referrals/${referralId}`)));
    await assertFails(getDoc(doc(unrelatedDb, `referrals/${referralId}`)));
    await assertFails(
      setDoc(doc(unrelatedDb, 'referrals/unrelated-write'), referral),
    );
  });

  it('enforces the full referral lifecycle and protects referral identity', async () => {
    await seedBase();
    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const otherAshaDb = authenticatedContext(environment, otherAshaUid).firestore();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const referral = {
      motherId,
      referringAshaId: assignedAshaUid,
      facility: 'Community Health Center',
      status: 'pending',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      acceptedAt: null,
      completedAt: null,
      cancelledAt: null,
    };
    const completedRef = doc(assignedDb, 'referrals/referral-completed');
    await assertSucceeds(setDoc(completedRef, referral));
    const initialCompleted = await assertSucceeds(getDoc(completedRef));
    const originalCreatedAt = initialCompleted.data().createdAt;
    await assertFails(updateDoc(completedRef, {
      status: 'completed', updatedAt: serverTimestamp(), completedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(completedRef, {
      status: 'accepted',
      facility: 'Different facility',
      updatedAt: serverTimestamp(),
      acceptedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(
      doc(otherAshaDb, 'referrals/referral-completed'),
      {status: 'accepted', updatedAt: serverTimestamp(), acceptedAt: serverTimestamp()},
    ));
    await assertFails(updateDoc(
      doc(patientDb, 'referrals/referral-completed'),
      {status: 'accepted', updatedAt: serverTimestamp(), acceptedAt: serverTimestamp()},
    ));

    await assertSucceeds(updateDoc(completedRef, {
      status: 'accepted',
      updatedAt: serverTimestamp(),
      acceptedAt: serverTimestamp(),
    }));
    const accepted = await assertSucceeds(getDoc(completedRef));
    await assertSucceeds(updateDoc(completedRef, {
      status: 'completed',
      updatedAt: serverTimestamp(),
      acceptedAt: accepted.data().acceptedAt,
      completedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(completedRef, {
      status: 'cancelled', updatedAt: serverTimestamp(), cancelledAt: serverTimestamp(),
    }));

    const pendingCancelledRef = doc(assignedDb, 'referrals/referral-pending-cancelled');
    await assertSucceeds(setDoc(pendingCancelledRef, referral));
    await assertSucceeds(updateDoc(pendingCancelledRef, {
      status: 'cancelled', updatedAt: serverTimestamp(), cancelledAt: serverTimestamp(),
    }));

    const acceptedCancelledRef = doc(assignedDb, 'referrals/referral-accepted-cancelled');
    await assertSucceeds(setDoc(acceptedCancelledRef, referral));
    await assertSucceeds(updateDoc(acceptedCancelledRef, {
      status: 'accepted', updatedAt: serverTimestamp(), acceptedAt: serverTimestamp(),
    }));
    const acceptedForCancel = await assertSucceeds(getDoc(acceptedCancelledRef));
    await assertSucceeds(updateDoc(acceptedCancelledRef, {
      status: 'cancelled',
      updatedAt: serverTimestamp(),
      acceptedAt: acceptedForCancel.data().acceptedAt,
      cancelledAt: serverTimestamp(),
    }));

    const completed = await assertSucceeds(getDoc(completedRef));
    assert.equal(completed.data().status, 'completed');
    assert.equal(completed.data().motherId, motherId);
    assert.equal(completed.data().referringAshaId, assignedAshaUid);
    assert.equal(completed.data().facility, referral.facility);
    assert.equal(completed.data().createdAt.toMillis(), originalCreatedAt.toMillis());
  });

  it('allows patient-owned appointments and denies access to unrelated appointments', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const appointment = {
      id: appointmentId,
      userId: patientUid,
      title: 'Antenatal visit',
      doctorName: 'Provider',
      date: Timestamp.fromMillis(Date.now() + 86_400_000),
      type: 'routine',
      status: 'pending',
      notes: '',
      reminderEnabled: false,
      createdAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(patientDb, `appointments/${appointmentId}`), appointment));
    await seedDocuments(environment, {
      'appointments/other-appointment': {
        ...appointment,
        id: 'other-appointment',
        userId: otherPatientUid,
      },
    });
    await assertSucceeds(getDoc(doc(patientDb, `appointments/${appointmentId}`)));
    await assertFails(getDoc(doc(patientDb, 'appointments/other-appointment')));
    await assertFails(
      setDoc(doc(patientDb, 'appointments/for-other-patient'), {
        ...appointment,
        id: 'for-other-patient',
        userId: otherPatientUid,
      }),
    );
  });

  it('denies unrelated ASHAs from reading another patient’s profile', async () => {
    await seedBase();
    const db = authenticatedContext(environment, otherAshaUid).firestore();
    await assertFails(getDoc(doc(db, `users/${patientUid}`)));
  });
  it('allows patient reads of linked appointments and assigned ASHA lifecycle updates', async () => {
    await seedBase();
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const appointment = {
      id: 'linked-appointment', motherId,
      date: Timestamp.fromMillis(Date.now() + 86_400_000),
      type: 'routine', status: 'pending', reminderEnabled: true,
      doctorName: 'Provider', facilityName: 'Clinic', appointmentKey: '',
      notes: '', createdBy: assignedAshaUid, createdAt: serverTimestamp(),
    };
    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const appointmentRef = doc(assignedDb, 'appointments/linked-appointment');
    await assertSucceeds(setDoc(appointmentRef, appointment));
    const appointmentRows = await assertSucceeds(patientDb
      .collection('appointments').where('motherId', '==', motherId).get());
    assert.equal(appointmentRows.size, 1);
    await seedDocuments(environment, {
      'appointments/another-mother-appointment': {
        ...appointment, id: 'another-mother-appointment', motherId: otherMotherId,
      },
    });
    await assertFails(getDoc(doc(patientDb, 'appointments/another-mother-appointment')));
    await assertFails(patientDb.collection('appointments').get());
    await assertSucceeds(updateDoc(appointmentRef, {
      status: 'scheduled', updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(appointmentRef, {
      status: 'completed', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(appointmentRef, {
      status: 'scheduled', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(appointmentRef, {
      status: 'completed', motherId: otherMotherId,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(
      authenticatedContext(environment, otherAshaUid).firestore(),
      'appointments/linked-appointment',
    ), {status: 'cancelled', updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(patientDb, 'appointments/linked-appointment'), {
      status: 'cancelled', updatedAt: serverTimestamp(),
    }));
  });

  it('allows patients to read only linked reminders and assigned ASHAs to create and manage them', async () => {
    await seedBase();
    const path = 'medicine_reminders/mother-reminder';
    const reminder = {
      motherId,
      medicineName: 'Prenatal medicine',
      instructions: 'Use the instructions provided by your clinician.',
      startDate: Timestamp.fromMillis(Date.UTC(2030, 0, 1)),
      endDate: Timestamp.fromMillis(Date.UTC(2030, 0, 5)),
      reminderTime: '08:30', active: true, createdBy: assignedAshaUid,
      createdAt: serverTimestamp(),
    };
    const assignedDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const reminderRef = doc(assignedDb, path);
    await assertSucceeds(setDoc(reminderRef, reminder));
    const patientDb = authenticatedContext(environment, patientUid).firestore();
    const reminderRows = await assertSucceeds(patientDb
      .collection('medicine_reminders').where('motherId', '==', motherId).get());
    assert.equal(reminderRows.size, 1);
    const assignedRows = await assertSucceeds(assignedDb
      .collection('medicine_reminders').where('motherId', '==', motherId).get());
    assert.equal(assignedRows.size, 1);
    await assertFails(authenticatedContext(environment, otherAshaUid).firestore()
      .collection('medicine_reminders').where('motherId', '==', motherId).get());
    await seedDocuments(environment, {
      'medicine_reminders/other-mother-reminder': {
        ...reminder, motherId: otherMotherId,
      },
    });
    await assertFails(getDoc(doc(patientDb, 'medicine_reminders/other-mother-reminder')));
    await assertSucceeds(updateDoc(reminderRef, {
      medicineName: 'Updated medicine',
      instructions: 'Updated supplied instructions',
      startDate: Timestamp.fromMillis(Date.UTC(2030, 0, 2)),
      endDate: Timestamp.fromMillis(Date.UTC(2030, 0, 6)),
      reminderTime: '09:15', updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(reminderRef, {
      active: false, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(reminderRef, {
      startDate: Timestamp.fromMillis(Date.UTC(2030, 0, 8)),
      endDate: Timestamp.fromMillis(Date.UTC(2030, 0, 6)),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(reminderRef, {
      reminderTime: '25:00', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(reminderRef, {
      motherId: otherMotherId, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(reminderRef, {
      createdBy: otherAshaUid, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(reminderRef, {
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(patientDb, path), {
      active: true, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(
      authenticatedContext(environment, otherAshaUid).firestore(), path,
    ), {active: true, updatedAt: serverTimestamp()}));
    await assertFails(setDoc(doc(patientDb, 'medicine_reminders/patient-created'), reminder));
  });
  it('moves reminder access to the new assigned ASHA after reassignment', async () => {
    await seedBase();
    const path = 'medicine_reminders/reassigned-reminder';
    const reminder = {
      motherId,
      medicineName: 'Prenatal medicine',
      instructions: 'Instructions provided by care team',
      startDate: Timestamp.fromMillis(Date.UTC(2030, 0, 1)),
      endDate: Timestamp.fromMillis(Date.UTC(2030, 0, 5)),
      reminderTime: '08:30',
      active: true,
      createdBy: assignedAshaUid,
      createdAt: serverTimestamp(),
    };
    const formerAshaDb = authenticatedContext(environment, assignedAshaUid).firestore();
    const formerReminderRef = doc(formerAshaDb, path);
    await assertSucceeds(setDoc(formerReminderRef, reminder));
    await seedDocuments(environment, {
      [`mothers/${motherId}`]: mother(patientUid, otherAshaUid),
    });

    const patientDb = authenticatedContext(environment, patientUid).firestore();
    await assertSucceeds(getDoc(doc(patientDb, path)));
    await assertFails(getDoc(formerReminderRef));
    await assertFails(updateDoc(formerReminderRef, {
      active: false, updatedAt: serverTimestamp(),
    }));
    const newReminderPath = 'medicine_reminders/created-after-reassignment';
    await assertFails(setDoc(doc(formerAshaDb, newReminderPath), {
      ...reminder,
      medicineName: 'New reminder by former ASHA',
    }));

    const currentAshaDb = authenticatedContext(environment, otherAshaUid).firestore();
    const currentReminderRef = doc(currentAshaDb, path);
    await assertSucceeds(getDoc(currentReminderRef));
    await assertSucceeds(setDoc(doc(currentAshaDb, newReminderPath), {
      ...reminder,
      medicineName: 'New reminder by current ASHA',
      createdBy: otherAshaUid,
    }));
    const currentRows = await assertSucceeds(currentAshaDb
      .collection('medicine_reminders').where('motherId', '==', motherId).get());
    assert.equal(currentRows.size, 2);
    await assertSucceeds(updateDoc(currentReminderRef, {
      active: false, updatedAt: serverTimestamp(),
    }));
    const saved = await assertSucceeds(getDoc(currentReminderRef));
    assert.equal(saved.data().motherId, motherId);
    assert.equal(saved.data().createdBy, assignedAshaUid);
    assert.equal(saved.data().active, false);
  });
});
