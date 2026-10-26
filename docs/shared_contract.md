
# AMMA Shared Backend Contract

Status: Proposed for frontend/backend integration  
Backend branch: `backend-uswa`  
Frontend branch: `frontend-munazza`

## 1. Firestore collections

- `users`
- `mothers`
- `health_records`
- `appointments`
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

## 5. Alerts

Collection: `alerts`

Contract fields:
- `id`
- `motherId`
- `type`
- `riskLevel`
- `message`
- `status`
- `createdAt`

Help-request types planned:
- `benefit_help`
- `appointment_request`

Near-term alert type planned:
- `nearing_delivery`

## 6. User profiles

Collection/document: `users/{uid}`

Existing fields:
- `id`
- `name`
- `email`
- `role`
- `createdAt`

Proposed additional field:
- `phone`: required for ASHA contact lookup when available

Roles:
- `asha`
- `patient`

## 7. Service interface plan

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

## 8. Security requirements

- Patients may read only their linked mother profile and associated records.
- ASHAs may read only mothers assigned to them and their associated records.
- Patients may create only permitted help-request alerts for their own mother.
- Users must not be able to assign themselves an arbitrary ASHA role.
- Enforce authorization in Firestore Security Rules, not only in Flutter UI.

## 9. Migration and integration rules

- Do not blindly rename `pregnancyWeek`, `userId`, or existing document IDs.
- Preserve legacy data until a migration strategy is tested.
- Do not merge overlapping UI files without reviewing both branches.
- Keep clinical risk assessment in the backend service layer.
- Confirm proposed additional fields with both developers before finalizing.
