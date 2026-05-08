// Semgrep test fixtures for no-eval and no-new-function rules.

const userCode = "alert(1)";

// ── eval: should flag ─────────────────────────────────────────────────────────

// ruleid: no-eval
eval(userCode);

// ruleid: no-eval
eval(req.body.code);

// ── eval: safe (use strict is the only allowed literal) ──────────────────────

// ok: no-eval
eval("use strict");

// ── new Function: should flag ─────────────────────────────────────────────────

// ruleid: no-new-function
const fn = new Function('return ' + userCode);

// ruleid: no-new-function
const fn2 = new Function('a', 'b', 'return a + b');
