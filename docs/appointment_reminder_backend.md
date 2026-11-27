# Appointment and reminder backend

Appointments remain in `appointments`. The service supports routine,
follow-up, and emergency types. Assigned ASHAs create mother appointments;
patients may create legacy self-owned pending appointments. Status transitions
are `pending -> scheduled/cancelled` and `scheduled -> completed/cancelled`.
Appointments are keyed by mother, exact timestamp, type, doctor, facility, and
optional `appointmentKey`. A distinct type/provider/facility or explicit key
allows another appointment at the same date/time. Repeating the same identity
targets the same ID; immutable-field rules reject an overwrite and the service
reports a duplicate. A direct Firestore writer with a different document ID can
still bypass uniqueness.

Patient appointment reads remain constrained to `userId == auth.uid`. ASHA
legacy callers are resolved only against mothers already assigned to that ASHA,
then queried by the matched stable `motherId`. Historical legacy ASHA
appointments with only `userId` and no `motherId` cannot be safely queried with
Firestore rules: a `userId` filter cannot prove that every result belongs to the
assigned mother, and Firestore cannot query for missing fields. No unsafe query
or live migration is performed. A trusted backend read or a future backfill of
the correct `motherId` is required to make those legacy records available to
ASHA queries.

Appointment history is retained. The deprecated `deleteAppointment` API now
transitions a cancellable appointment to `cancelled`; rules prohibit deletion.

Medicine reminders are stored in a new `medicine_reminders` collection because
the repository had no reminder model or service. An assigned ASHA supplies the
medicine name, instructions, date range, and 24-hour reminder time. No medicine,
dose, or frequency advice is generated. Deterministic IDs and immutable-field
rules reject duplicate reminder creation through this service. Direct writes by
an authorized ASHA can choose a different document ID; strong uniqueness across
arbitrary direct writes would need a trusted backend or a rule-verifiable
canonical ID scheme.

## Notification and clinical-trigger limits

The project has Firebase Auth and Firestore only; it has no Firebase Messaging,
local-notification package, notification initialization, permission handling,
background scheduler, or delivery callback. `reminderEnabled` and a
`medicine_reminders` document mean only that reminder data is stored. No local
notification is scheduled or delivered by this backend.

`expectedDeliveryDate` is an optional field in the mother profile service. No
nearing-delivery lead time or trigger exists, so none is inferred here. The
maternal knowledge source contains a government immunization schedule reference
but marks it `clinical_review_required` and directs families to confirm the
individual next dose using the MCP/vaccination card and an ASHA/provider. Do not
generate personalized vaccination reminders until a reviewed rule, source,
patient data fields, and authorized trigger are approved.

## Emulator verification required

Verify patient reads/creates only own legacy appointments; assigned ASHA creates,
reads, and transitions appointments for assigned mothers; unrelated users are
denied; deletes are denied; immutable fields cannot be edited; transition skips
and reversals are denied; duplicate concurrent service creation produces one
document with the other caller receiving a duplicate error; the ASHA mother-ID
query is authorized; and unbackfilled legacy ASHA appointment queries are not
issued. For reminders,
verify only the assigned ASHA can create/toggle active state, patient and ASHA
reads are mother-scoped, unrelated users are denied, invalid fields/date/time
are rejected, duplicate concurrent service creates are rejected, and no
notification delivery is represented in Firestore. Rules are not deployed by
this change.

## Frontend work for Munazza

Add appointment create/list/history UI, allow the ASHA to choose routine,
follow-up, or emergency type and enter facility/doctor details when known, and
display status and reminder preference. Add ASHA medicine-reminder create/list/
active-toggle UI with instructions entered by an authorized clinician. Clearly
label this as a stored reminder; no notification will arrive until a separate
approved local or push notification integration is built. Nearing-delivery and
vaccination reminders need clinically reviewed trigger criteria and corresponding
mother data before they can be surfaced.
