# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in Nudgy, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email **hammad@barq.dev** with:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You should receive a response within 48 hours. We will work with you to understand the issue and coordinate a fix before any public disclosure.

## Scope

Nudgy runs a local HTTP server on `127.0.0.1:9847`. Security considerations include:

- **Local-only binding**: The server only listens on localhost, never on `0.0.0.0`
- **Token authentication**: A randomly-generated auth token is required for all requests, preventing other local processes from injecting fake events
- **Input validation**: All incoming JSON payloads are validated before processing
- **Path traversal protection**: Session IDs and paths from hook events are sanitized before filesystem access
- **CORS rejection**: Cross-origin browser requests are explicitly denied
- **Keychain storage**: Credentials are stored in macOS Keychain with device-only access restrictions

## Network Egress

Nudgy makes **no outbound network requests** by default. If you configure the optional Usage Quota feature with a claude.ai session key, Nudgy will periodically contact `https://claude.ai/api/` to fetch usage data. This feature is entirely opt-in and can be disabled by removing the session key from Settings.
