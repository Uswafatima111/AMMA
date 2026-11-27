# Patient, mother and health-record identity

Firebase Authentication UID identifies a signed-in user. A mother profile is
identified by its Firestore document ID. Linked profiles store the patient's
Auth UID in `mothers.patientUid`; ASHA access is based on
`mothers.assignedAshaId`. New health records store the stable mother document
ID in `health_records.motherId`.

Patient service lookups derive the UID from the active Firebase Auth session and
resolve the matching `patientUid` link. Legacy methods keep their signatures,
but patient callers can only ask for their own UID. ASHA legacy lookups resolve
the supplied old identifier only among mothers assigned to that signed-in ASHA.
Health-record streams query either the resolved stable `motherId` or a narrowly
scoped legacy `userId == authenticated UID` fallback when no mother link is
available. They no longer scan the full health-record collection.

## Legacy data limits

Records with a reliable `motherId` remain addressable through that mother ID.
When a patient has no `patientUid` link, the old UID-as-mother-document-ID
convention is used only if that document exists and does not point to another
patient. If a linked patient has legacy records whose `motherId` does not equal
the linked stable mother document ID (or records have only `userId`), the
mother-scoped stream does not combine those records automatically. When there
is no resolvable mother link, the legacy service signature can still read
records with `userId == authenticated UID`. Other ambiguous legacy records
need reviewed, explicit linkage before any migration; this work does not
rewrite or delete them.

The client checks for a duplicate `patientUid` link before creating a linked
profile, but Firestore rules cannot guarantee uniqueness across documents.
Two ASHAs could concurrently create profiles linked to the same patient, and
an ASHA cannot query another ASHA's private assignment to detect it. The
patient lookup detects multiple links and fails safely. A trusted backend or a
securely maintained patient-to-mother pointer with transactional creation is
needed for global uniqueness.

## Emulator verification

Use the Firestore Emulator to verify that patients can query mothers by
`patientUid` and records by `motherId`; assigned ASHAs can query mothers and
records by `assignedAshaId`/`motherId`; unrelated users are denied; patients
cannot create clinical records; and records cannot be updated or deleted.
Also test a patient with no link, a legacy UID-keyed mother, duplicate links,
and reassignment of an ASHA. Rules are local only and have not been deployed.

## Frontend follow-up

No screen changes are included. The patient dashboard currently continues to
pass the Auth UID to legacy service signatures; the services now resolve the
linked mother internally. Future UI work should pass the returned stable mother
ID to mother-scoped health-record and appointment APIs. ASHA mother-detail
screens should use the mother document ID instead of `userId` when requesting
records. This avoids ambiguous legacy lookup behavior.
