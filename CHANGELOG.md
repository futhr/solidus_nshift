# Changelog

## 0.1.0.alpha.1 — Unreleased

- Test published Solidus 4.7 with Rails 8.1 and refresh runtime dependencies.
- Prevent implicit HTTP mutation retries, defer booking until order commit, and recover interrupted cancellations.
- Preserve JSON decimal precision and validate store, connection, and session context for quotes.
- Apply record-level admin permissions and require valid order tokens for CSRF exemptions.
- Invalidate OAuth tokens on secret rotation and bound the fallback cache.
- Serialize tracking imports and reject fractional provider status IDs.
- Load admin screens only when the legacy Solidus backend is installed.
- Isolate logging failures, sanitize request notifications, and block network access in tests.
- Add core-only boot and package verification checks.

Initial implementation:

- Replaced the legacy `spree-unifaun` implementation with the `solidus_nshift` gem and `SolidusNshift` namespace.
- Added nShift Checkout v2 OAuth/session/options and exact Solidus dynamic rates.
- Added validated pickup-point continuity and stale-context rejection.
- Added Delivery REST booking, multi-document metadata, download, cancellation, and reconciliation.
- Added optional Shipment Data lookup and idempotent, monotonic event import.
- Added encrypted per-store connection configuration and authorized admin operations.
- Added deterministic provider contracts and supported Solidus/Rails test coverage.
- Added the documented Delivery `shipmentPrint` envelope, complete sender data, and configurable PDF/ZPL print media.
- Added durable pre-enqueue intents, queue-failure telemetry, bounded reconciliation, and database adoption constraints.
- Added PostgreSQL concurrency and MySQL portability tests to CI.
- Added a guarded RubyGems trusted-publishing workflow and release runbook.
