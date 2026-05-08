// Semgrep test fixtures for no-child-process-exec-with-variable
// and no-child-process-execsync-with-variable rules.
// Run: semgrep --test node-web/tests --config node-web/semgrep.yml

const { exec, execSync } = require('child_process');
const cp = require('child_process');

// ── Exec: should flag ─────────────────────────────────────────────────────────

const userInput = process.argv[2];

// ruleid: no-child-process-exec-with-variable
require('child_process').exec(userInput, (err, out) => console.log(out));

// ruleid: no-child-process-exec-with-variable
exec(userInput, (err, out) => console.log(out));

// ruleid: no-child-process-execsync-with-variable
require('child_process').execSync(userInput);

// ruleid: no-child-process-execsync-with-variable
execSync(userInput);

// ── Exec: safe usage (literal string) — should NOT flag ──────────────────────

// ok: no-child-process-exec-with-variable
require('child_process').exec('ls -la', (err, out) => console.log(out));

// ok: no-child-process-exec-with-variable
exec('git status', (err, out) => console.log(out));

// ok: no-child-process-execsync-with-variable
execSync('npm install');
