# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

### Contact

- **Email:** security@example.com
- **Response time:** We aim to respond within 48 hours

### Process

1. **Do not** open a public issue for security vulnerabilities
2. Email the security team with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact assessment
3. We will acknowledge receipt and provide a timeline for resolution
4. A fix will be developed and tested before public disclosure

### Scope

This policy applies to the latest release of this project.

## Security Practices

- All credentials are managed through Secrets Manager / environment variables
- Pre-commit hooks enforce secret scanning via gitleaks
- CI/CD pipeline includes automated security scanning
- Configuration defaults follow the principle of least privilege

## Credential Rotation

If credentials are suspected to be compromised:

1. Rotate all affected credentials immediately
2. Review access logs for unauthorized usage
3. Clean git history if credentials were committed
4. File a security incident report
