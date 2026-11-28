# Appointment and reminder backend

Appointments remain in `appointments`. Assigned ASHAs create records for a
mother they are assigned to; patients read appointments for their linked
`motherId` and their own legacy `userId` rows. The patient dashboard now uses
the stable mother ID query and merges its own UID-scoped legacy rows. A
collection-wide query is not authorized. Legacy ASHA appointments with only
`userId` and no `motherId` cannot be safely queried and still require an
approved migration or trusted read path.

Appointment types are `routine`, `followUp`, and `emergency`. New records must
have a future timestamp and an initial `pending` or `scheduled` status. The
allowed transitions are `pending -> scheduled|cancelled` and
`scheduled -> completed|cancelled`; terminal records are retained. The
assigned ASHA may update status only. Identity and creation fields cannot be
changed. Patient-created legacy appointments remain self-owned and pending.

Medicine reminders are stored in `medicine_reminders`. The assigned ASHA
creates, edits supplied medicine/instruction/date/time fields, and toggles
`active`. Patients read reminders only for their linked mother. Mother,
creator, and creation timestamp are immutable. Dates must be ordered and time
must be 24-hour `HH:mm`; instructions are supplied by the ASHA, not generated
or clinically reviewed by this feature.

The ASHA mother-details screen lists reminders through a `motherId`-scoped
stream and provides create, edit, and active-toggle controls. Service
transactions and Firestore rules verify the mother's current assignment for
each mutation; reassigned former ASHAs lose read/write access and the new
assigned ASHA can manage existing reminders. Widget tests cover the ASHA form
and its create/edit/deactivate flow.

## Device-local reminder scheduling

There was no Firebase Messaging or local notification setup. The app now uses
`flutter_local_notifications` with the device timezone for local appointment
and medicine reminders. A patient must press **Enable local reminders** and
grant OS notification permission. The patient dashboard subscribes only to
that patient's linked mother appointments/reminders and own legacy appointment
query. It schedules at most the next 60 occurrences, replacing its prior
pending local schedules when scoped data changes. Appointment notifications
are scheduled at the appointment timestamp; medicine reminders use each
inclusive local date and the ASHA-entered time. Notification text is generic;
medicine/instruction details remain in the app.

This is device-local scheduling only: no Firebase Cloud Messaging, remote
delivery, ASHA notification, or delivery receipt exists. Notification display
depends on permission, device/OS scheduling and battery policy. Schedules
beyond the 60-item window are refreshed when the patient reopens the dashboard
and enables reminders again. The emulator and unit tests validate authorization
and schedule planning, not physical delivery on a handset. Android has the
notification permission, reboot receiver, and scheduled notification receiver
configured; iOS permission is requested at runtime.

## Still outside this feature

`expectedDeliveryDate` is an optional mother-profile field. No nearing-delivery
lead time or trigger is implemented. The maternal knowledge source contains a
government immunization schedule reference but marks it
`clinical_review_required`; individualized vaccination reminders must wait for
reviewed criteria, required patient data, and an authorized trigger.

## Verification expectations

Rules Emulator coverage checks own linked/legacy appointment reads, assigned
ASHA appointment status transitions, patient and unrelated-ASHA denials,
patient reminder reads, assigned-ASHA reminder create/edit/activation, invalid
dates/times, immutable ownership/creator/creation fields, and unauthorized
updates. Unit tests cover reminder edit authorization and local schedule
planning. These tests do not establish physical notification delivery or
deployed Firebase behavior. Rules have not been deployed by this work.
