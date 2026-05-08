# OWASP Web Security Testing Guide (WSTG) — Checklist

> Version reference: OWASP WSTG v4.2  
> Status key: `[ ]` Not started · `[~]` In progress · `[x]` Done · `[N/A]` Not applicable

---

## 1. Information Gathering (WSTG-INFO)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| INFO-01 | Conduct Search Engine Discovery (Google dorks, Shodan) | `[ ]` | |
| INFO-02 | Fingerprint Web Server | `[ ]` | |
| INFO-03 | Review Webserver Metafiles for Information Leakage (robots.txt, sitemap.xml) | `[ ]` | |
| INFO-04 | Enumerate Application on Webserver | `[ ]` | |
| INFO-05 | Review Webpage Content for Information Leakage (HTML comments, JS) | `[ ]` | |
| INFO-06 | Identify Application Entry Points | `[ ]` | |
| INFO-07 | Map Execution Paths Through Application | `[ ]` | |
| INFO-08 | Fingerprint Web Application Framework | `[ ]` | |
| INFO-09 | Fingerprint Web Application | `[ ]` | |
| INFO-10 | Map Application Architecture | `[ ]` | |

---

## 2. Configuration and Deployment Management (WSTG-CONF)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| CONF-01 | Test Network Infrastructure Configuration | `[ ]` | |
| CONF-02 | Test Application Platform Configuration | `[ ]` | |
| CONF-03 | Test File Extension Handling for Sensitive Information | `[ ]` | |
| CONF-04 | Review Old Backup and Unreferenced Files | `[ ]` | |
| CONF-05 | Enumerate Infrastructure and Application Admin Interfaces | `[ ]` | |
| CONF-06 | Test HTTP Methods | `[ ]` | OPTIONS, TRACE, DELETE |
| CONF-07 | Test HTTP Strict Transport Security (HSTS) | `[ ]` | |
| CONF-08 | Test RIA Cross Domain Policy | `[ ]` | |
| CONF-09 | Test File Permission | `[ ]` | |
| CONF-10 | Test for Subdomain Takeover | `[ ]` | |
| CONF-11 | Test Cloud Storage | `[ ]` | S3 buckets, Azure blobs |
| CONF-12 | Test for Content Security Policy | `[ ]` | |

---

## 3. Identity Management (WSTG-IDNT)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| IDNT-01 | Test Role Definitions | `[ ]` | |
| IDNT-02 | Test User Registration Process | `[ ]` | |
| IDNT-03 | Test Account Provisioning Process | `[ ]` | |
| IDNT-04 | Testing for Account Enumeration and Guessable User Account | `[ ]` | |
| IDNT-05 | Testing for Weak or Unenforced Username Policy | `[ ]` | |

---

## 4. Authentication (WSTG-ATHN)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| ATHN-01 | Testing for Credentials Transported over an Encrypted Channel | `[ ]` | |
| ATHN-02 | Testing for Default Credentials | `[ ]` | |
| ATHN-03 | Testing for Weak Lock Out Mechanism | `[ ]` | |
| ATHN-04 | Testing for Bypassing Authentication Schema | `[ ]` | |
| ATHN-05 | Testing for Vulnerable Remember Password | `[ ]` | |
| ATHN-06 | Testing for Browser Cache Weaknesses | `[ ]` | |
| ATHN-07 | Testing for Weak Password Policy | `[ ]` | |
| ATHN-08 | Testing for Weak Security Question/Answer | `[ ]` | |
| ATHN-09 | Testing for Weak Password Change or Reset Functionalities | `[ ]` | |
| ATHN-10 | Testing for Weaker Authentication in Alternative Channel | `[ ]` | |

---

## 5. Authorization (WSTG-ATHZ)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| ATHZ-01 | Testing Directory Traversal / File Include | `[ ]` | |
| ATHZ-02 | Testing for Bypassing Authorization Schema | `[ ]` | |
| ATHZ-03 | Testing for Privilege Escalation | `[ ]` | |
| ATHZ-04 | Testing for Insecure Direct Object References (IDOR) | `[ ]` | |
| ATHZ-05 | Testing for OAuth Weaknesses | `[ ]` | |

---

## 6. Session Management (WSTG-SESS)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| SESS-01 | Testing for Session Management Schema | `[ ]` | |
| SESS-02 | Testing for Cookies Attributes | `[ ]` | Secure, HttpOnly, SameSite |
| SESS-03 | Testing for Session Fixation | `[ ]` | |
| SESS-04 | Testing for Exposed Session Variables | `[ ]` | |
| SESS-05 | Testing for Cross Site Request Forgery (CSRF) | `[ ]` | |
| SESS-06 | Testing for Logout Functionality | `[ ]` | |
| SESS-07 | Testing Session Timeout | `[ ]` | |
| SESS-08 | Testing for Session Puzzling | `[ ]` | |
| SESS-09 | Testing for Session Hijacking | `[ ]` | |
| SESS-10 | Testing JSON Web Tokens | `[ ]` | alg:none, weak secret |

---

## 7. Input Validation (WSTG-INPV)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| INPV-01 | Testing for Reflected Cross Site Scripting (XSS) | `[ ]` | |
| INPV-02 | Testing for Stored Cross Site Scripting (XSS) | `[ ]` | |
| INPV-03 | Testing for HTTP Verb Tampering | `[ ]` | |
| INPV-04 | Testing for HTTP Parameter Pollution | `[ ]` | |
| INPV-05 | Testing for SQL Injection | `[ ]` | |
| INPV-06 | Testing for LDAP Injection | `[ ]` | |
| INPV-07 | Testing for XML Injection | `[ ]` | XXE |
| INPV-08 | Testing for SSI Injection | `[ ]` | |
| INPV-09 | Testing for XPath Injection | `[ ]` | |
| INPV-10 | Testing for IMAP/SMTP Injection | `[ ]` | |
| INPV-11 | Testing for Code Injection | `[ ]` | eval(), exec() |
| INPV-12 | Testing for Command Injection | `[ ]` | |
| INPV-13 | Testing for Format String Injection | `[ ]` | |
| INPV-14 | Testing for Incubated Vulnerability | `[ ]` | |
| INPV-15 | Testing for HTTP Splitting/Smuggling | `[ ]` | |
| INPV-16 | Testing for HTTP Incoming Requests | `[ ]` | |
| INPV-17 | Testing for Host Header Injection | `[ ]` | |
| INPV-18 | Testing for Server-Side Template Injection (SSTI) | `[ ]` | |
| INPV-19 | Testing for Server-Side Request Forgery (SSRF) | `[ ]` | |
| INPV-20 | Testing for Mass Assignment | `[ ]` | |

---

## 8. Error Handling (WSTG-ERRH)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| ERRH-01 | Testing for Improper Error Handling | `[ ]` | Stack traces in responses |
| ERRH-02 | Testing for Stack Traces | `[ ]` | |

---

## 9. Cryptography (WSTG-CRYP)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| CRYP-01 | Testing for Weak Transport Layer Security | `[ ]` | TLS 1.0/1.1, RC4 |
| CRYP-02 | Testing for Padding Oracle | `[ ]` | |
| CRYP-03 | Testing for Sensitive Information Sent via Unencrypted Channels | `[ ]` | |
| CRYP-04 | Testing for Weak Encryption | `[ ]` | MD5, SHA1 for passwords |

---

## 10. Business Logic (WSTG-BUSL)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| BUSL-01 | Test Business Logic Data Validation | `[ ]` | |
| BUSL-02 | Test Ability to Forge Requests | `[ ]` | |
| BUSL-03 | Test Integrity Checks | `[ ]` | |
| BUSL-04 | Test for Process Timing | `[ ]` | Race conditions |
| BUSL-05 | Test Number of Times a Function Can Be Used Limits | `[ ]` | |
| BUSL-06 | Testing for the Circumvention of Work Flows | `[ ]` | |
| BUSL-07 | Test Defenses Against Application Misuse | `[ ]` | |
| BUSL-08 | Test Upload of Unexpected File Types | `[ ]` | |
| BUSL-09 | Test Upload of Malicious Files | `[ ]` | |
| BUSL-10 | Test Payment Functionality | `[ ]` | |

---

## 11. Client-Side Testing (WSTG-CLNT)

| ID | Test | Status | Notes |
|----|------|--------|-------|
| CLNT-01 | Testing for DOM-Based XSS | `[ ]` | |
| CLNT-02 | Testing for JavaScript Execution | `[ ]` | |
| CLNT-03 | Testing for HTML Injection | `[ ]` | |
| CLNT-04 | Testing for Client-Side URL Redirect | `[ ]` | |
| CLNT-05 | Testing for CSS Injection | `[ ]` | |
| CLNT-06 | Testing for Client-Side Resource Manipulation | `[ ]` | |
| CLNT-07 | Test Cross Origin Resource Sharing (CORS) | `[ ]` | |
| CLNT-08 | Testing for Cross Site Flashing | `[ ]` | |
| CLNT-09 | Testing for Clickjacking | `[ ]` | X-Frame-Options |
| CLNT-10 | Testing WebSockets | `[ ]` | |
| CLNT-11 | Test Web Messaging | `[ ]` | postMessage() |
| CLNT-12 | Testing Browser Storage | `[ ]` | localStorage, sessionStorage |
| CLNT-13 | Testing for Cross Site Script Inclusion (XSSI) | `[ ]` | |
| CLNT-14 | Testing for Reverse Tabnapping | `[ ]` | |

---

## Sign-off

| Tester | Date | Scope | Result |
|--------|------|-------|--------|
| | | | |
