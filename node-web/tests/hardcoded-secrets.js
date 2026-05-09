// Semgrep test fixtures for no-hardcoded-jwt-secret and
// no-hardcoded-password-in-object rules.

const jwt = require('jsonwebtoken');

// ── JWT: should flag ──────────────────────────────────────────────────────────

// ruleid: no-hardcoded-jwt-secret
const token = jwt.sign({ userId: 1 }, "supersecret", { expiresIn: '1h' });

// ruleid: no-hardcoded-jwt-secret
const payload = jwt.verify(token, "supersecret");

// ── JWT: safe — secret from environment ──────────────────────────────────────

// ok: no-hardcoded-jwt-secret
const token2 = jwt.sign({ userId: 1 }, process.env.JWT_SECRET, { expiresIn: '1h' });

// ok: no-hardcoded-jwt-secret
const payload2 = jwt.verify(token2, process.env.JWT_SECRET);

// ── Hardcoded object credentials: should flag (production code only) ─────────

// ruleid: no-hardcoded-password-in-object
const dbConfig = { password: "hunter2" };

// ruleid: no-hardcoded-password-in-object
const apiCreds = { apiKey: "sk-abc123" };

// ── Safe: credential read from env ───────────────────────────────────────────

// ok: no-hardcoded-password-in-object
const safeConfig = { password: process.env.DB_PASSWORD };
