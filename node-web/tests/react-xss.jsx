// Semgrep test fixtures for no-dangerously-set-inner-html and no-href-javascript.

// ── dangerouslySetInnerHTML: should flag ──────────────────────────────────────

// ruleid: no-dangerously-set-inner-html
const Unsafe = ({ html }) => <div dangerouslySetInnerHTML={{__html: html}} />;

// ruleid: no-dangerously-set-inner-html
const UnsafeSpan = ({ content }) => <span dangerouslySetInnerHTML={{__html: content}} />;

// ── Safe alternative: render via React children (no dangerouslySetInnerHTML) ──

// ok: no-dangerously-set-inner-html
const Safe = ({ text }) => <div>{text}</div>;

// ok: no-dangerously-set-inner-html
const SafeParagraph = ({ children }) => <p className="content">{children}</p>;

// ── javascript: href: should flag ────────────────────────────────────────────

// ruleid: no-href-javascript
const BadLink = () => <a href="javascript:alert(1)">click</a>;

// ruleid: no-href-javascript
const BadLink2 = ({ fn }) => <a href={"javascript:" + fn}>click</a>;

// ── Safe link ─────────────────────────────────────────────────────────────────

// ok: no-href-javascript
const GoodLink = ({ url }) => <a href={url}>click</a>;

// ok: no-href-javascript
const GoodLink2 = () => <a href="https://example.com">click</a>;
