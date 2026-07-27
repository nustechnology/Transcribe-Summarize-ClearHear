# Security policy

## Supported versions

Security fixes are applied on the default branch (`main`) and included in the
next release. Older tagged builds are not backported unless noted in a release.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Before publishing this policy, maintainers must guarantee at least one tested
private reporting channel:

1. **GitHub private vulnerability reporting** — on the repository page, use
   **Security → Report a vulnerability** (**must be enabled and tested** for this
   repository before relying on this policy).
2. **Monitored security contact** — a private mailbox or equivalent private
   channel owned by maintainers (for example, `security@your-domain.tld`).

If GitHub private reporting is not enabled, this policy must include a concrete
monitored private channel before release.

Include as much detail as you can:

- Affected platform(s) (Android / iOS) and app version or commit
- Steps to reproduce
- Impact (e.g. local data exposure, unexpected network use, crash → RCE)
- Any suggested fix

We aim to acknowledge reports within **7 business days**. Please give us a
reasonable window to investigate and ship a fix before public disclosure.

### Maintainer checklist (publish gate)

- Confirm `Security -> Report a vulnerability` is enabled on the repository.
- Submit a test private report and confirm maintainers receive notifications.
- If GitHub private reporting is unavailable, publish and monitor a dedicated
  security contact channel in this file.

## Scope notes

ClearHear is designed for **on-device** audio processing. Expected network use
is limited to downloading missing ML model files from Hugging Face when assets
are absent. Reports that transcripts, audio, or embeddings leave the device
without user action are high priority.

Out of scope (unless they reveal a ClearHear bug):

- Issues solely in upstream packages or model weights (report upstream)
- Attacks that require a compromised device / physical access without a
  ClearHear-specific weakness
- Social-engineering or phishing against end users
