# Firestore Rules Emulator tests

This directory contains security tests that load the repository's actual
`firestore.rules`. Fixtures are written with rules disabled; all assertions
use authenticated or unauthenticated client contexts against the Firestore
Emulator.

From the repository root, install the isolated test dependencies once:

```powershell
npm.cmd install --prefix rules-tests
```

The Firebase CLI and a Java runtime must also be installed and available on
`PATH` (`firebase --version` and `java -version`). The project already uses
the Firebase CLI for its Functions workflow; it is not duplicated as a local
dependency in this test package.

Run the suite with the emulator managed by Firebase CLI:

```powershell
npm.cmd --prefix rules-tests run test:emulator
```

The command uses the non-production project ID `demo-amma-rules` and the
Firestore Emulator on port `8080`. It does not deploy rules or access the
configured production project. Emulator startup may download the emulator
binary the first time.

The final test records the intended denial of an ASHA reading an unrelated
patient profile. It is expected to fail with the current rules, which allow an
ASHA to read any `users` document whose role is `patient`; this is reported as
a security finding rather than weakening or adjusting the test.
