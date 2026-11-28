
# AMMA Shared Backend Contract

Status: Proposed for frontend/backend integration  
Backend branch: `backend-uswa`  
Frontend branch: `frontend-munazza`

## 1. Firestore collections

- `users`
- `mothers`
- `health_records`
- `appointments`
- `medicine_reminders`
- `alerts`

## 2. Mother document

Collection/document: `mothers/{motherId}`

Required contract fields:
- `id`: string, stable mother ID
- `name`: string
- `age`: integer
- `phone`: string
- `gestationalWeeks`: integer
- `bloodPressure`: string
- `weight`: number
- `hemoglobin`: number
- `symptoms`: list of strings
- `emergencyContact`: string
- `riskLevel`: `low`, `moderate`, or `high`
- `assignedAshaId`: Firebase Auth UID of assigned ASHA
- `createdAt`: Firestore Timestamp

Proposed additional fields:
- `patientUid`: optional Firebase Auth UID linked to the mother
- `expectedDeliveryDate`: optional Firestore Timestamp
- `status`: optional legacy field pending migration

The mother document ID is the stable mother ID, not necessarily the patient's
Firebase Auth UID.

## 3. Health records

Collection: `health_records`

Contract fields:
- `id`
- `motherId`
- `date`
- `bloodPressure`
- `hemoglobin`
- `weight`
- `symptoms`
- `riskLevel`
- `matchedRules`
- `explanation`
- `recommendation`
- `ruleVersion`

Legacy documents may contain `userId` and `recordedAt`. Do not delete or rename
these fields until a compatibility and migration plan is approved.

New records must include a valid stable `motherId` and are readable by the
patient only through that mother's verified `patientUid` link (or the legacy
UID-keyed mother relationship). An optional `userId` on a canonical record
must match the patient linked to that mother; when the mother has no
`patientUid`, it may match only the legacy UID-keyed mother ID. A mismatched
`userId` does not grant a patient access, even if it equals that patient's
Auth UID. The assigned ASHA retains access through the mother's current
`assignedAshaId`.

The only patient fallback for a legacy health record is a record with no
`motherId` and `userId` equal to the authenticated patient UID, when that
patient profile has no `assignedMotherId` and no UID-keyed mother document
exists. New writes cannot use this legacy-only shape. Once a mother link is
available, callers must use the verified mother-scoped query; ambiguous legacy
records require reviewed migration rather than trusting `userId` alone.

## 4. Appointments

Collection: `appointments`

Contract fields:
- `id`
- `motherId`
- `date`: Firestore Timestamp
- `type`: `routine`, `followUp`, or `emergency`
- `status`
- `reminderEnabled`: boolean

Proposed additional fields:
- `doctorName`
- `facilityName`

Legacy documents may contain `userId` and `title`.

New ASHA-created appointments use stable `motherId`; patients read only their
linked mother's appointments and their own legacy `userId` records. Assigned
ASHAs create appointments for their assigned mothers. Status starts as
`pending` or `scheduled`; allowed changes are `pending -> scheduled|cancelled`
and `scheduled -> completed|cancelled`. Appointments are retained rather than
deleted. `id`, `motherId`/legacy `userId`, date, type, creator, and creation
time are immutable after creation. Patient reads use scoped `motherId` and
authenticated-UID legacy queries, not a collection-wide scan.

## 5. Medicine reminders

Collection: `medicine_reminders`

Fields:
- `motherId`: stable ID of `mothers/{motherId}`
- `medicineName`: ASHA-entered name
- `instructions`: ASHA-entered instructions; the app does not recommend a
  medicine or dose
- `startDate`, `endDate`: Firestore Timestamps, inclusive date range
- `reminderTime`: local 24-hour `HH:mm`
- `active`: boolean
- `createdBy`: creating ASHA UID
- `createdAt`: Firestore Timestamp
- `updatedAt`: Firestore Timestamp, when edited or activated/deactivated

Only the ASHA currently assigned to the mother can create, edit, activate, or
deactivate a reminder. Patients can read reminders only for their linked
mother. `motherId`, creator, and creation time remain immutable. The assigned
ASHA may edit the supplied medicine name, instructions, dates, and time.

Patients can opt in to device-local appointment and medicine notifications.
They are scheduled on that device from authorized Firestore streams; there is
no Firebase Cloud Messaging, remote delivery, ASHA notification, or delivery
receipt. Local schedules are limited to the next 60 occurrences and refresh
while the patient dashboard is open. Device permission, OS scheduling policy,
and reopening the app to refresh the rolling window affect delivery.

## 6. Alerts

Collection: `alerts`

Contract fields:
- `id`
- `motherId`
- `type`
- `riskLevel`
- `message`
- `status`
- `createdAt`

Patient help-request fields:
- `userId`: authenticated patient UID; must agree with the verified mother link
- `assignedAshaId`: ASHA UID assigned on the linked mother record

Allowed patient help-request types:
- `benefit_help`
- `appointment_request`

Patient requests include the contract fields above, use the patient's stable
`motherId` and the mother's current `assignedAshaId`, and start with
`riskLevel: low` and `status: open`. Creation is allowed only when the
authenticated patient owns the linked mother and the supplied ASHA matches
that mother record. Firestore rules enforce this relationship; client-side
checks are not the authorization boundary.

Patients read alerts associated with their own linked mother through the
verified relationship and query by `motherId`; `userId` is not an independent
authorization grant. Assigned ASHAs query alerts by `motherId` and can read
alerts only for mothers currently assigned to them. `AlertService.getAlerts`
and `watchAlertsForMother` use mother-scoped queries. Rules validate any
present `userId` against the patient actually linked to that mother. The
legacy exception is limited to explicitly validated legacy document reads;
it does not permit collection-wide or arbitrary `userId` queries. Existing
ASHA-created mother alerts remain supported.

`AlertModel.status` remains a string; `AlertService` and Firestore rules
validate the supported patient-request transitions. A request starts at
`open`. The assigned ASHA may acknowledge it with `open -> read`, then move it
through `read -> pending|accepted|cancelled`, `pending -> accepted|cancelled`,
and `accepted -> completed|cancelled`. From `open`, the ASHA may also move
directly to `pending`, `accepted`, or `cancelled`. `completed` and `cancelled`
are terminal. `resolved` remains in the legacy service status vocabulary but
is not a supported patient-request transition.

Only the currently assigned ASHA may update a patient help request. The
request's `assignedAshaId` records the assignment at creation and is
immutable; authorization follows the mother record's current assignment.
Updates may change `status` only; `userId`, `motherId`, `assignedAshaId`,
`type`, and `createdAt` are immutable. Patients may read requests tied to their
own mother but cannot acknowledge, update, or resolve them. Alert deletion
remains denied. These are stored Firestore records, not delivered
notifications.

Near-term alert type planned:
- `nearing_delivery`

## 7. User profiles

Collection/document: `users/{uid}`

Existing fields:
- `id`
- `name`
- `email`
- `role`
- `createdAt`

Proposed additional field:
- `phone`: required for ASHA contact lookup when available

Linked-patient field:
- `assignedMotherId`: mother document ID for a patient linked to a mother record

`assignedMotherId` references `mothers/{motherId}` by that document's ID. It is
written together with the linked mother record during patient-linked
registration by the assigned ASHA. It is optional for patient profiles that are
not linked yet.
When present, the referenced mother must identify the same patient through
`patientUid` and the current ASHA through `assignedAshaId`. The patient owns
their profile and retains self-access. An ASHA may read the patient profile
only when the referenced mother confirms both identities; ASHA assignment is
recorded on the mother document, not chosen by the patient profile alone.
Legacy records whose mother document ID is the patient's UID remain supported
by the legacy lookup rule.

Roles:
- `asha`
- `patient`

## 8. Service interface plan

Mother service:
- `createMother(...)`: create a mother profile and return its stable ID.
- `getMotherById(motherId)`: retrieve a mother profile or return null.
- `getMotherForPatient(patientUid)`: retrieve the linked mother or return null.
- `getMothersAssignedToAsha(ashaUid)`: stream mothers assigned to an ASHA.

ASHA service:
- `getAshaContact(ashaUid)`: return name and phone, or null if unavailable.

Appointment service:
- `getUpcomingAppointment(motherId)`: return the next future appointment or null.

Authentication service:
- Sign in with email and password.
- Return the authenticated UID and role from the trusted user profile.
- Return a clear error when authentication or role lookup fails.

## 9. Security requirements

- Patients may read only their linked mother profile and associated records.
- ASHAs may read only mothers assigned to them and their associated records.
- Patients may create only permitted help-request alerts for their own mother.
- Users must not be able to assign themselves an arbitrary ASHA role.
- Enforce authorization in Firestore Security Rules, not only in Flutter UI.

## 10. Migration and integration rules

- Do not blindly rename `pregnancyWeek`, `userId`, or existing document IDs.
- Preserve legacy data until a migration strategy is tested.
- Do not merge overlapping UI files without reviewing both branches.
- Keep clinical risk assessment in the backend service layer.
- Confirm proposed additional fields with both developers before finalizing.
