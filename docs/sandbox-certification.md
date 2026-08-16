# nShift sandbox certification record

The automated suite is deterministic and credential-free. Production enablement additionally requires a merchant-owned nShift test account because product entitlements, carrier contracts, service codes, sender Quick IDs, and document formats cannot be inferred from public API documentation.

## Evidence status

Status: **awaiting merchant test credentials and entitlement confirmation**.

This is an external release gate for each enabled capability, not a mocked success claim. Checkout and Delivery can ship independently of optional Shipment Data entitlement.

## Required run

Record the date, nShift test account/actor identifier (never the secret), Solidus/Rails versions, enabled capabilities, connection ID, service codes, and sender Quick ID.

Capture sanitized screenshots with these names:

1. `01-admin-connection-sanitized.png`
2. `02-checkout-shipping-options.png`
3. `03-checkout-pickup-selected.png`
4. `04-admin-fulfillment-booked.png`
5. `05-admin-label-download.png`
6. `06-admin-tracking-events.png`
7. `07-timeout-reconciliation.png`

Never include credentials, access tokens, API keys, real customer names/addresses, label barcodes, tracking numbers, or unredacted provider request IDs.

## Acceptance record

| Check | Result | Evidence / note |
| --- | --- | --- |
| OAuth token and four-hour Checkout session | Pending | |
| Swedish home options | Pending | |
| Swedish pickup option and offered point validation | Pending | |
| Changed destination/package invalidates old selection | Pending | |
| Checkout partial shipment created once | Pending | |
| Delivery shipment and all parcel documents created once | Pending | |
| PDF and ZPL retrieval | Pending | |
| Forced ambiguous timeout reconciles without rebooking | Pending | |
| Cancellation behavior | Pending | |
| Shipment Data lookup/events, if entitled | Pending | |

The production connection remains inactive and Delivery test mode remains enabled until every in-scope row passes.
