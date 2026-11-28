# Emergency and referral lifecycle

Emergency requests remain in `emergency_requests`, separate from `alerts`. A
signed-in patient can create a request only for their own UID. The service
associates the sole mother record linked by `patientUid`, or falls back to the
legacy mother document keyed by patient UID. If no mother or assigned ASHA is
available, the request is retained without an assignment; no ASHA receives it
through the assigned-request query. Status moves are `active -> responded ->
resolved`, with responder and resolution UIDs and server timestamps. Resolution
preserves the original responder metadata, including when a different ASHA
resolves after reassignment. This only records an in-app request; it does not
contact an ambulance or emergency service.

Emergency access follows the mother's current `assignedAshaId`; the request's
`assignedAshaId` remains the original assignment for history. The service
subscribes to the signed-in ASHA's assigned mothers, then queries requests for
those explicit mother IDs. It fails explicitly above 10 assigned mothers
rather than issue a query that may exceed Firestore rules document-lookup
limits or silently omit requests. Supporting larger caseloads while retaining
the current `QuerySnapshot` API requires a trusted aggregation endpoint or a
service API that can merge several per-mother query streams; frontend integration
would then be required for that changed API.

## Orphan emergency request limitation

The service resolves a linked mother before writing an emergency request. The
rules also reject an unassigned (`motherId: null`) request when the patient's
`assignedMotherId` profile pointer is present or a legacy `mothers/{patientUid}`
record exists. Patients cannot clear that pointer themselves. Existing
generated-ID mother records without `assignedMotherId` backfill remain a gap:
Firestore Rules cannot query the `mothers` collection to prove that no other
linked document exists. Backfill those records or move emergency creation to a
trusted backend before treating the orphan check as complete. A genuinely
unlinked patient can still create an unassigned request; no ASHA receives it
through the assigned-request query.

Referrals use a new `referrals` collection because the repository had the
`ReferralStatus` enum but no referral model, service, or collection workflow.
An assigned ASHA creates a referral with mother ID, facility name, status, and
timestamps. The workflow supports `pending -> accepted/cancelled` and
`accepted -> completed/cancelled`. Facility text is entered by the ASHA; no
hospital contacts or external booking behavior is provided.

## Emulator verification required

The Firestore Emulator suite now verifies patient emergency creation for a
linked mother; rejection of a wrong mother/assignment and an orphan request
from a linked patient; protection of the patient link; emergency transitions,
immutable identity, and denial of patient/unrelated-ASHA updates; and referral
acceptance, completion, pending/accepted cancellation, identity protection, and
denial of invalid or unauthorized updates. It also confirms an unlinked patient
can still create an unassigned request. Remaining emulator gaps include
emergency/referral behavior across ASHA reassignment, live query changes, and
the 10-mother limit. Rules are not deployed by this work.

## Frontend integration for Munazza

The existing ASHA emergency screen calls `getActiveEmergencies()` and remains
unchanged per task constraints; the service now follows the signed-in ASHA's
live assigned-mother set. Ensure any request/status rendering accepts
`responded` requests. The patient SOS wording now makes clear it submits an
in-app request and does not summon an ambulance. Add referral create/list/status
UI for ASHA workflows and show facility and lifecycle timestamps. Handle
missing mother/ASHA assignment as an unsent-to-worker request state rather than
implying it has been routed. Existing legacy `respondToEmergency` caller passes
the signed-in UID as `responderId`; the service verifies it.
