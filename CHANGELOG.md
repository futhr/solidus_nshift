# Changelog

## 0.1.0.alpha.1 - 2026-08-16

- Replaced the legacy `spree-unifaun` implementation with the `solidus_nshift` gem and `SolidusNshift` namespace.
- Added nShift Checkout v2 OAuth/session/options and exact Solidus dynamic rates.
- Added validated pickup-point continuity and stale-context rejection.
- Added Delivery REST booking, multi-document metadata, download, cancellation, and reconciliation.
- Added optional Shipment Data lookup and idempotent, monotonic event import.
- Added encrypted per-store connection configuration and authorized admin operations.
- Added deterministic provider contracts and supported Solidus/Rails test coverage.
- Added the documented Delivery `shipmentPrint` envelope, complete sender data, and configurable PDF/ZPL print media.
- Added durable pre-enqueue intents, queue-failure telemetry, bounded reconciliation, and database adoption constraints.
- Added PostgreSQL concurrency and MySQL portability certification to CI.
- Added a guarded RubyGems trusted-publishing workflow and release runbook.
