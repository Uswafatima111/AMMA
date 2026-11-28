/** Reusable client contexts for Firestore Rules Emulator tests. */
export function authenticatedContext(environment, uid, claims = {}) {
  return environment.authenticatedContext(uid, claims);
}

export function unauthenticatedContext(environment) {
  return environment.unauthenticatedContext();
}

/** Seed fixtures without granting the test user privileged client access. */
export async function seedDocuments(environment, documents) {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [path, data] of Object.entries(documents)) {
      await db.doc(path).set(data);
    }
  });
}
