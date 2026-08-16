# Changelog

## 0.1.0.alpha.1 - 2026-08-16

- Replaced the legacy `spree-unifaun` implementation with the `solidus_nshift` gem and `SolidusNshift` namespace.
- Added nShift Checkout v2 OAuth/session/options and exact Solidus dynamic rates.
- Added validated pickup-point continuity and stale-context rejection.
- Added Delivery REST booking, multi-document metadata, download, cancellation, and reconciliation.
- Added optional Shipment Data lookup and idempotent, monotonic event import.
- Added encrypted per-store connection configuration and authorized admin operations.
- Added deterministic provider contracts and supported Solidus/Rails test coverage.
