# nShift test-account certification

There is no public nShift Docker image or local emulator for the APIs used by this gem. The automated suite therefore uses synthetic, sanitized responses for repeatable contract and failure testing. Before production, run this checklist against an nShift-provisioned test account.

The hosted Shipment Server demo is for a different nShift product and cannot certify this integration.

## Access to request

Ask nShift support or the merchant's account contact for only the capabilities being enabled:

- **Checkout:** a Portal test tenant, a Checkout connection with Swedish home and pickup options, and an OAuth client allowed to use the Public Checkout API.
- **Delivery:** Delivery REST/APIConnect access, an API key, developer ID, sender Quick ID, service codes, label media, and the REST API Shipment History entitlement used for safe reconciliation.
- **Tracking (optional):** a Portal OAuth client allowed to use Shipment Data, plus test shipment events.

Confirm that Delivery test mode produces TEST labels and does not forward carrier EDI. Never reuse production credentials in the test connection.

The API hosts do not change for this run: Checkout and Tracking isolation comes from the nShift-issued tenant and credentials, while Delivery uses its request-level test flag. In a staging store, create a dedicated connection, enable only the granted capabilities, keep Delivery test mode on, and use synthetic customer data.

## Run record

| Field | Value |
| --- | --- |
| Date and tester | |
| nShift test tenant or account ID | |
| Solidus / Rails / gem versions | |
| Connection ID and enabled capabilities | |
| Service codes and sender Quick ID | |
| Label format and print media | |

Do not record secrets, tokens, customer details, barcodes, tracking numbers, or full provider request IDs.

## Checks

Mark optional rows `N/A`. Link sanitized screenshots or logs in the evidence column.

| Check | Result | Evidence / note |
| --- | --- | --- |
| Checkout authenticates, creates a session, and returns the expected Swedish home and pickup options | Pending | |
| Pickup selection rejects an unoffered point; changing the address or package invalidates the old selection | Pending | |
| Finalization creates one Checkout partial shipment and one Delivery shipment with the configured sender, receiver, and service | Pending | |
| Re-running the booking job creates no duplicate shipment or document | Pending | |
| Every parcel document downloads; the configured PDF or ZPL format and print media produce the expected label | Pending | |
| A forced post-dispatch timeout becomes `reconciliation_pending` and Shipment History adopts the remote shipment without rebooking | Pending | |
| Cancellation reaches the expected provider and local state | Pending | |
| Shipment Data finds the order and imports test events idempotently | Pending | |

Keep the production connection inactive until every enabled capability passes. Create it with separate credentials, and turn off Delivery test mode only during the approved production cutover.
