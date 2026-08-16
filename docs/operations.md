# Operations guide

## Fulfillment states

| State | Meaning | Safe operator action |
| --- | --- | --- |
| `unbooked` | Local intent exists; no mutation completed | Book |
| `booking` | A worker claimed an operation | Wait; reconcile if the worker disappeared |
| `partial_created` | Checkout partial shipment exists; Delivery is disabled or not yet complete | Inspect configuration |
| `booked` | Delivery shipment ID is persisted | Refresh documents, sync tracking, or cancel |
| `reconciliation_pending` | A mutation may have succeeded remotely | Reconcile; never blindly rebook |
| `rejected` | Provider definitively rejected the request | Correct data/credentials, then book again |
| `canceled` | Cancellation was confirmed | No booking retry under this intent |

The operation table is the audit boundary. `in_progress` or `unknown` mutations are never automatically dispatched again.

## Reconciliation runbook

1. Open **Admin → nShift → Fulfillments** and inspect the operation kind, attempt count, provider code, and stable merchant reference.
2. For an unknown Delivery booking, click **Reconcile**. A matching provider shipment is adopted locally, including tracking and document references.
3. If no shipment is found, leave the fulfillment pending. Confirm account/environment, lookup window, and provider permissions. Do not use **Book** as an assumption that the first call failed.
4. For an unknown Checkout partial shipment, search nShift using the merchant/order context and resolve manually; this adapter deliberately has no automatic replay.
5. For an unknown cancellation, verify the provider shipment state before another action.

## Jobs

- `SolidusNshift::BookShipmentJob` — explicit post-finalization mutation; it does not auto-retry ambiguous outcomes.
- `SolidusNshift::ReconcileBookingJob` — read-only Delivery lookup and local adoption.
- `SolidusNshift::SyncTrackingJob` — optional Shipment Data lookup/import.
- `SolidusNshift::RefreshDocumentsJob` — refreshes metadata only and cannot create a shipment.
- `SolidusNshift::CancelFulfillmentJob` — persisted cancellation mutation.

Configure the application's Active Job backend for durable production queues. Alert on jobs that exhaust retries and on fulfillments remaining `booking` or `reconciliation_pending` beyond the merchant's service objective.

## Labels

The gem stores provider document IDs, format, description, and content type—not permanent binary copies. Admin download streams at most 25 MiB from nShift after verifying the stored fulfillment relationship. PDF magic and response content type are checked by the client.

Provider print references may expire; refresh document metadata or establish merchant-owned archival outside this gem if retention regulations require it.

## Tracking

Tracking is optional. A first sync searches Shipment Data by the stable Delivery order reference within a bounded time window, stores the shipment UUID, and imports valid events. Repeated imports are idempotent. Provider absence never changes the booking state.

## Logs and metrics

Subscribe to `solidus_nshift.request` with `ActiveSupport::Notifications`. Payload metadata includes API family, operation, connection/fulfillment identifiers, and error class; credentials and address payloads are not emitted.

Rails parameter filtering includes all credential field names. Keep application log access restricted and never log provider request bodies at the HTTP transport boundary.

## Credential rotation

Enter only the new secret in the connection form; blank secret fields retain existing encrypted values. OAuth access tokens are cached per connection/capability and expire automatically. For immediate token invalidation, restart processes or clear the configured cache after rotating credentials.
