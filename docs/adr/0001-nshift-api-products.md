# ADR 0001: Separate nShift product adapters

- Status: Accepted
- Date: 2026-08-16

## Context

nShift exposes several products with different hosts, credentials, resource semantics, and account entitlements. Treating them as one “Unifaun API” would mix authentication boundaries and make mutation recovery unsafe.

The supported products researched for this release are:

- Checkout v2 at `https://api.nshiftportal.com/checkout`, using OAuth client credentials from `https://account.nshiftportal.com/idp/connect/token`;
- Delivery REST v1 at `https://api.unifaun.com/rs-extapi/v1`, using Basic authentication with an API key ID and secret plus `developerId` in shipment data;
- Shipment Data at `https://api.nshiftportal.com/track/shipmentdata`, using Portal OAuth credentials that may require separate entitlement.

Shipment Server is a separate nShift product and is not a hidden fallback.
Its hosted demo environment cannot test these adapters, and there is no public local container for them.

Manifests, consolidated shipments, Delivery Cloud, dangerous-goods fields, and customs/non-EU shipment data are outside the initial release.

## Decision

The gem uses independent `Checkout::Client`, `Delivery::Client`, and `ShipmentData::Client` adapters and independent capability credentials.

Checkout is the rating/session authority and creates the selected partial-shipment resource after Solidus order completion. Delivery REST is the selected v1 book-and-print adapter: it sends the documented `shipmentPrint` object (`printConfig` plus nested `shipment`), creates one non-return, non-consolidated shipment, lists/retrieves PDF or ZPL documents, and cancels shipments. Shipment Data is optional and read-only for order-number search and shipment/package events.

Test/live separation is represented by different connection records. Delivery's `test` request property defaults to true; it prints TEST labels and disables EDI forwarding. Checkout and Shipment Data environment access is determined by the issued Portal credentials and connection configuration.

## Mutation and idempotency consequences

These APIs do not document one universal idempotency header. Therefore the integration:

1. persists a unique fulfillment per Solidus shipment;
2. persists a unique, revisioned operation per mutation kind before the HTTP call;
3. fingerprints the exact request, permitting a new revision only after a definitive rejection;
4. includes `solidus:<store-code>:<shipment-number>:1` as Delivery `orderNo` and external reference;
5. enforces unique provider-resource adoption and operation states in the database;
6. never holds a database transaction across HTTP;
7. treats timeout, transport ambiguity, or malformed mutation responses as unknown rather than failed;
8. searches Delivery Shipment History by the stable merchant reference before any operator considers another booking.

An absent reconciliation result does not authorize automatic rebooking. Checkout partial-shipment lookup is not available in the chosen adapter, so its unknown outcomes require manual nShift verification.

## Documents, cancellation, and tracking

Document metadata is retained locally; binary labels are fetched by scoped shipment/document IDs through an authorized admin endpoint. Provider `href` values are not used as redirects. Multiple document rows are preserved.

Cancellation is its own persisted mutation operation. An ambiguous cancellation is not repeated automatically.

Shipment Data imports are idempotent by provider event ID. Unknown codes are retained, timestamps remain timezone-aware, and out-of-order events cannot regress a terminal status.

## Entitlements and release evidence

Each merchant must verify in an nShift test account that its contract grants the enabled Checkout connection, Delivery REST service/carrier codes, document formats, and optional Shipment Data access. Missing optional Shipment Data entitlement does not disable Checkout or Delivery.

Primary provider references:

- [nShift API overview](https://helpcenter.nshift.com/hc/en-us/articles/26836198242076-API-overview-What-s-changing)
- [Getting started with Checkout API](https://helpcenter.nshift.com/hc/en-us/articles/13495941082396-Getting-started-with-nShift-Checkout-API)
- [Delivery REST shipment schema](https://api.unifaun.com/rs-extapi/v1/documentation/ShipmentPrint.jsonschema)
- [Delivery REST object reference](https://nshiftdelivery.helpcenter.nshift.com/hc/en-us/articles/23353390912796-REST-API-objects)
- [Delivery REST API definition](https://api.unifaun.com/rs-extapi/v1/documentation/root-resource-v1.raml)
- [Shipment Data API](https://helpcenter.nshift.com/hc/en-us/articles/360021438180-ShipmentData-API)
