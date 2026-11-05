---
name: security-review
description: "Assess requested security reviews or audits and changed nShift OAuth credentials, shipment/checkout ownership, label destinations or booking/retry boundaries. Trace secret handling and uncertain external effects; exclude ordinary shipping-label layout changes."
---

# Security review

Read [the repository instructions](../../../AGENTS.md), SECURITY, CONTRIBUTING
and the affected delivery contract. Map the store actor, order/shipment,
connection/provider account and allowed external operation.

Follow checkout and shipment selectors through authorization, retained booking
intent, OAuth token selection, HTTP requests and returned label/tracking data.
Inspect [token custody](../../../lib/solidus_nshift/oauth/token_provider.rb),
including account/cache separation, refresh/concurrency, expiry and redaction.
Do not treat a cached provider token as permission to act on another shipment.

Inspect provider URLs, redirects, downloads, payload bounds, PDF/ZPL handling
and error/log output wherever the requested path consumes them. Establish actual
caller control and validation before alleging SSRF or file disclosure. Track
booking/cancellation identity and reconciliation after timeout, process failure
or a retried callback; an uncertain booking must not become a fresh duplicate.

Select existing OAuth, transport, request and shipment tests for the affected
boundary. Dummy responses prove their modeled contract only.
[Provider qualification](../../../docs/sandbox-certification.md) owns real
test-account checks; the audit does not implicitly authorize those operations
or certify a carrier/device.

## Scope, evidence and execution

For the requested review, record the revision and relevant working-tree changes,
checked entry/control/effect paths and deferred or excluded areas. A focused
review does not require a whole-repository audit.

Establish each claim against the strongest current control and owning contract.
Confirmed findings need a complete reachable boundary trace and evidence for
the stated consequence. Keep decisive unobserved facts as `needs_validation`,
with the exact missing check and no severity; reject disproved claims.
Distinguish source inspection, inspected tests, executed local tests and live
evidence. Group duplicate root causes and recheck previous findings against
current source and conditions.

Use the existing validation owner for authorized dummy-data regressions.
Executing untrusted code or hostile native/availability checks requires verified
OS isolation, no external networking, a sanitized environment and resource/time
limits. If unavailable, leave that execution unverified and continue source
review. A review grants no live/provider operations or agent-permission changes.
Independent verification is conditional on authorized, available delegation;
otherwise state the single-reviewer limit. Return findings in chat unless the
requested deliverable and repository contract permit a report.

Audit-method background: [Cloudflare's source-first workflow](https://github.com/cloudflare/security-audit-skill/tree/c1c8a8c1471069fb0e188eeaff69b8e8db6564a8/skills/security-audit).
