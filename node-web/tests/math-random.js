// Semgrep test fixtures for no-math-random-for-secrets rule.
// This rule is INFO severity — it highlights all Math.random() calls for
// manual review without blocking the build.

// ruleid: no-math-random-for-secrets
const id = Math.random().toString(36).slice(2);

// ruleid: no-math-random-for-secrets
const delay = Math.random() * 1000;

// ── Safe alternative ──────────────────────────────────────────────────────────

// ok: no-math-random-for-secrets
const { randomUUID } = require('crypto');
const secureId = randomUUID();

// ok: no-math-random-for-secrets
const { randomBytes } = require('crypto');
const token = randomBytes(32).toString('hex');
