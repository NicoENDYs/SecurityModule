# API Security Checklist

> Based on OWASP API Security Top 10 (2023) and REST/GraphQL best practices.  
> Status key: `[ ]` Not started · `[~]` In progress · `[x]` Done · `[N/A]` Not applicable

---

## OWASP API Security Top 10 (2023)

| # | Risk | Test | Status | Notes |
|---|------|------|--------|-------|
| API1 | Broken Object Level Authorization (BOLA/IDOR) | Access resources of other users by manipulating IDs in path/query | `[ ]` | |
| API2 | Broken Authentication | Test for weak tokens, missing expiry, JWT alg:none | `[ ]` | |
| API3 | Broken Object Property Level Authorization | Can a lower-privileged user read/write sensitive fields? | `[ ]` | |
| API4 | Unrestricted Resource Consumption | Rate limiting on expensive endpoints (search, upload, export) | `[ ]` | |
| API5 | Broken Function Level Authorization | Can a regular user call admin-only endpoints? | `[ ]` | |
| API6 | Unrestricted Access to Sensitive Business Flows | Bulk operations, automated abuse (credential stuffing, scraping) | `[ ]` | |
| API7 | Server-Side Request Forgery (SSRF) | Webhooks, URL import features pointing to internal IPs | `[ ]` | |
| API8 | Security Misconfiguration | Default credentials, verbose errors, open CORS, debug endpoints | `[ ]` | |
| API9 | Improper Inventory Management | Shadow APIs, deprecated v1 endpoints still reachable | `[ ]` | |
| API10 | Unsafe Consumption of APIs | Third-party APIs consumed without input validation | `[ ]` | |

---

## Authentication & Authorization

| Test | Status | Notes |
|------|--------|-------|
| API keys rotated and stored securely (not in code) | `[ ]` | |
| JWT: verify `alg` header not `none`, `RS256` or `ES256` preferred | `[ ]` | |
| JWT: check `exp`, `iss`, `aud` claims are validated | `[ ]` | |
| OAuth 2.0: `state` parameter used to prevent CSRF | `[ ]` | |
| OAuth 2.0: PKCE enforced for public clients | `[ ]` | |
| Refresh tokens are single-use and rotated | `[ ]` | |
| All endpoints require authentication (no accidental public routes) | `[ ]` | |
| Scope/permission checks on every protected resource | `[ ]` | |

---

## Transport Security

| Test | Status | Notes |
|------|--------|-------|
| API served over HTTPS only (HTTP redirects to HTTPS) | `[ ]` | |
| HSTS header present | `[ ]` | |
| TLS 1.2 minimum (TLS 1.3 preferred) | `[ ]` | |
| Certificate pinning evaluated for mobile clients | `[ ]` | |
| No sensitive data in URLs (tokens, passwords in query string) | `[ ]` | |

---

## Input Validation

| Test | Status | Notes |
|------|--------|-------|
| All inputs validated (type, length, format, range) | `[ ]` | |
| JSON schema validation on request bodies | `[ ]` | |
| File upload: type, size, and content validation | `[ ]` | |
| GraphQL depth and complexity limits configured | `[ ]` | |
| GraphQL introspection disabled in production | `[ ]` | |
| SQL/NoSQL injection protection (parameterized queries/ODMs) | `[ ]` | |
| Mass assignment protection (allowlist of writable fields) | `[ ]` | |

---

## Rate Limiting & Throttling

| Test | Status | Notes |
|------|--------|-------|
| Per-user rate limits enforced | `[ ]` | |
| Per-IP rate limits as secondary defense | `[ ]` | |
| Rate limit headers returned (`X-RateLimit-*`, `Retry-After`) | `[ ]` | |
| Expensive operations (export, bulk, send email) individually limited | `[ ]` | |
| Account lockout on repeated auth failures | `[ ]` | |

---

## Response & Data Exposure

| Test | Status | Notes |
|------|--------|-------|
| Responses do not leak internal IDs, stack traces, or server info | `[ ]` | |
| Error messages are generic (no field-level enumeration) | `[ ]` | |
| Pagination enforced (no endpoint returns unbounded lists) | `[ ]` | |
| Sensitive fields (password hash, PII) excluded from responses | `[ ]` | |
| `Content-Type` header present and correct | `[ ]` | |

---

## Security Headers (REST APIs)

| Header | Expected Value | Status | Notes |
|--------|----------------|--------|-------|
| `Content-Security-Policy` | `default-src 'none'` (for API responses) | `[ ]` | |
| `X-Content-Type-Options` | `nosniff` | `[ ]` | |
| `X-Frame-Options` | `DENY` | `[ ]` | |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | `[ ]` | |
| `Cache-Control` | `no-store` for sensitive endpoints | `[ ]` | |
| `Access-Control-Allow-Origin` | Explicitly set, never `*` for credentialed requests | `[ ]` | |

---

## Logging & Monitoring

| Test | Status | Notes |
|------|--------|-------|
| Auth events (login, logout, failure) logged with IP and user-agent | `[ ]` | |
| Authorization failures produce alerts | `[ ]` | |
| Logs do not contain passwords, tokens, or PII | `[ ]` | |
| Anomaly detection / WAF in place | `[ ]` | |

---

## Sign-off

| Tester | Date | API Version | Result |
|--------|------|-------------|--------|
| | | | |
