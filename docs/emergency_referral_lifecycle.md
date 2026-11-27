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

The service chooses the linked mother and assignment from Firestore, but a
patient can bypass it and write directly to Firestore. The emergency create
rule accepts `motherId: null` and `assignedAshaId: null` without checking whether
any mother document has `patientUid` equal to that patient. Firestore Rules
cannot query the mothers collection to prove that no link exists. A trusted
backend that authenticates the patient and looks up the linked mother before
creation is the safest future fix. A securely maintained patient-to-mother
pointer in the patient profile, writable only by trusted administrative or
backend code and checked by rules, is another option. Neither is implemented
here.

Referrals use a new `referrals` collection because the repository had the
`ReferralStatus` enum but no referral model, service, or collection workflow.
An assigned ASHA creates a referral with mother ID, facility name, status, and
timestamps. The workflow supports `pending -> accepted/cancelled` and
`accepted -> completed/cancelled`. Facility text is entered by the ASHA; no
hospital contacts or external booking behavior is provided.

## Emulator verification required

Run the Firestore Emulator with the checked-in `firestore.rules` before release.
Verify patient creation and own-request read; denial of another patient's
request; denial of a patient or unrelated ASHA reading or mutating a request;
former ASHA denial and newly assigned ASHA read/respond/resolve after mother
reassignment; preservation of response metadata on resolution; rejection of
skipped/reversed transitions and edits to immutable request fields; and
unassigned-request denial to ASHAs. Test the direct-write orphan case to
demonstrate the documented rule limitation. Also verify query authorization for
the live assigned-mother query, including a mother reassignment while the
stream is open, and test the 10-mother limit. For referrals, verify creation,
read and update by the currently assigned ASHA, reassignment, and denial for
unrelated ASHAs. Rules are not deployed by this change.

## Frontend integration for Munazza

The existing ASHA emergency screen calls `getActiveEmergencies()` and remains
unchanged per task constraints; the service now follows the signed-in ASHA's
live assigned-mother set. Ensure any request/status rendering accepts
`responded` requests. The patient SOS wording should make clear it submits an
in-app request and does not summon an ambulance. Add referral create/list/status
UI for ASHA workflows and show facility and lifecycle timestamps. Handle
missing mother/ASHA assignment as an unsent-to-worker request state rather than
implying it has been routed. Existing legacy `respondToEmergency` caller passes
the signed-in UID as `responderId`; the service verifies it.
