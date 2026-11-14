# Security Policy

## Supported versions

Security fixes are prioritised for the latest maintained Beta on the default development line. Older immutable Beta APKs may not receive backported fixes.

## Reporting a vulnerability

**Do not report exploitable vulnerabilities in a public GitHub issue.**

Use GitHub's private vulnerability reporting feature from the repository Security tab if it is enabled. If private reporting is unavailable, contact the maintainer privately through the GitHub profile:

https://github.com/rabit001

Do not include passwords, access tokens, signing keys, service-account credentials, production user data, or other secrets in a report.

## What to include

A useful report includes:

- A concise description and impact.
- Affected app version, commit, platform, and environment.
- Reproduction steps using test accounts and non-production data.
- Relevant logs with tokens, email addresses, phone numbers, and personal data removed.
- Any suggested mitigation, if known.

## Scope and safe testing

- Do not access, modify, or delete another person's data.
- Do not perform destructive testing against production Firebase services.
- Use local Firebase emulators and disposable test accounts.
- Do not publish exploit details before the maintainer has had a reasonable opportunity to investigate and prepare a fix.

## Secrets and Firebase configuration

Firebase client configuration files are not service-account credentials, but they still must be reviewed before publication. Never commit private keys, service-account JSON, upload keystores, passwords, App Check debug tokens, or local environment files.

Report accidental secret exposure privately and rotate/revoke the affected credential promptly.
