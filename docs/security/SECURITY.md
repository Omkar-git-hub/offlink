# Security Policy

## Reporting

Do not publish sensitive vulnerability details in a public issue.

For the repository's production release, a private security reporting mechanism should be configured through GitHub Security Advisories or another documented channel.

## Development rules

Never commit:
- private keys
- passwords
- API tokens
- test credentials
- real user messages
- real location data

Security-sensitive changes require:
- tests
- documentation
- review
- CI verification
