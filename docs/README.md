# Architecture and code map

This page describes how `solidus_nshift` fits into a Solidus application. Operational recovery belongs in the [operations guide](operations.md); provider access and release evidence belong in the [test-account checklist](sandbox-certification.md).

## System context

The engine separates checkout quoting, fulfillment mutations, and tracking because nShift exposes them as different products with different credentials and failure modes.

```mermaid
flowchart LR
  Customer["Customer storefront"]
  Operator["Solidus administrator"]

  subgraph Host["Solidus application"]
    Checkout["Stock estimator and shipping rates"]
    Events["order_finalized event"]
    Queue["Active Job adapter"]
    Database[("Application database")]
    Cache[("Shared Rails cache")]
  end

  subgraph Gem["solidus_nshift"]
    Pickup["Pickup-selection endpoint"]
    Admin["Admin controllers"]
    Rates["RateProvider"]
    Fulfillment["Booking and reconciliation services"]
    Tracking["Tracking and document services"]
    CheckoutClient["Checkout client"]
    DeliveryClient["Delivery client"]
    ShipmentDataClient["Shipment Data client"]
  end

  CheckoutAPI["nShift Checkout v2"]
  DeliveryAPI["nShift Delivery REST"]
  TrackingAPI["nShift Shipment Data"]

  Customer --> Checkout
  Customer --> Pickup
  Operator --> Admin
  Checkout --> Rates
  Events --> Queue --> Fulfillment
  Admin --> Fulfillment
  Admin --> Tracking
  Admin --> Database
  Pickup --> Database
  Rates <--> Cache
  Rates --> Database
  Fulfillment --> Database
  Tracking --> Database
  Rates --> CheckoutClient --> CheckoutAPI
  Fulfillment --> CheckoutClient
  Fulfillment --> DeliveryClient --> DeliveryAPI
  Tracking --> DeliveryClient
  Tracking --> ShipmentDataClient --> TrackingAPI
```

Solidus order authorization protects pickup selection; admin actions use the normal Solidus admin abilities.

## Source layout

| Path | Responsibility |
| --- | --- |
| `lib/solidus_nshift.rb` | Public entry point, configuration, value objects, HTTP handling, OAuth, and provider clients |
| `lib/solidus_nshift/engine.rb` | Rails engine, parameter filtering, admin menu, model extensions, estimator extension, and event subscription |
| `lib/solidus_nshift/checkout/` | Checkout sessions, package requests, option normalization, and service points |
| `lib/solidus_nshift/delivery/` | Delivery REST client and validated shipment/document responses |
| `lib/solidus_nshift/shipment_data/` | Shipment lookup, event normalization, and tracking client |
| `app/models/solidus_nshift/` | Connections and durable checkout, fulfillment, mutation, document, and tracking state |
| `app/services/solidus_nshift/` | Workflow orchestration, payload construction, validation, persistence, and reconciliation |
| `app/jobs/solidus_nshift/` | Queue entry points and retry policy |
| `app/controllers/solidus_nshift/` | Storefront pickup selection and authorized admin actions |
| `db/migrate/` | Tables, uniqueness rules, check constraints, and operation revisions |
| `spec/` | Provider contract fixtures, service behavior, requests, integration cases, and database concurrency |

Runtime dependencies point inward toward small provider clients and persisted records. Provider clients do not know about Solidus models.

```mermaid
flowchart TB
  Entry["Solidus estimator, event subscriber, jobs, and controllers"]
  Workflows["Application services"]
  Records["Active Record models"]
  Clients["Provider clients and response objects"]
  HTTP["HTTP transport and response handling"]
  Provider["nShift APIs"]
  DB[("Database constraints")]

  Entry --> Workflows
  Workflows --> Records
  Workflows --> Clients
  Clients --> HTTP --> Provider
  Records --> DB
```

## Checkout quoting

The estimator extension adds nShift rates alongside rates returned by Solidus. It serializes the package once, uses a digest of destination, contents, units, store, connection, shipment, and stock location as the cache key, and persists the provider context with the resulting shipping rate.

```mermaid
sequenceDiagram
  participant E as Solidus estimator
  participant R as RateProvider
  participant K as Rails cache
  participant C as Checkout client
  participant N as nShift Checkout
  participant D as RateSelection
  participant S as Storefront
  participant P as Pickup endpoint

  E->>R: rate_quotes(package)
  R->>R: serialize package and context digest
  R->>K: fetch connection + digest
  alt cache miss
    R->>C: create session
    C->>N: POST session
    N-->>C: session ID and expiry
    R->>C: request shipping options
    C->>N: POST package and destination
    N-->>C: priced options and pickup points
    C-->>R: normalized session and options
    R-->>K: cache session and options
  end
  R->>R: filter kind and service allowlist
  R-->>E: cheapest exact-decimal quote
  E->>D: build selection with context and offered points
  S->>P: choose an offered pickup point
  P->>P: authorize order and lock checkout
  P->>D: persist offered point
  P->>P: revalidate shipment context
```

Each Solidus shipping method yields at most one nShift rate. Shops that expose both home and pickup delivery should configure separate shipping methods. Currency mismatch, malformed data, authentication failure, or transport failure returns no nShift rate; other Solidus shipping methods remain available.

## Fulfillment booking

Finalizing an order creates the local fulfillment intent before the job is enqueued. The job validates that the chosen rate is complete and still matches the shipment, then runs the enabled provider mutations in order.

```mermaid
sequenceDiagram
  participant B as Spree event bus
  participant I as FulfillmentIntent
  participant Q as Active Job
  participant S as BookingService
  participant O as OperationIntent
  participant C as nShift Checkout
  participant D as nShift Delivery
  participant DB as Database

  B->>I: order_finalized(shipment)
  I->>DB: create unique fulfillment intent
  I-->>B: persisted fulfillment
  B->>Q: enqueue BookShipmentJob
  Q->>S: perform(shipment)
  S->>S: validate selected rate and context
  opt Checkout enabled
    S->>O: checkout_partial + payload fingerprint
    O->>DB: persist operation revision
    S->>DB: claim operation row
    S->>C: create partial shipment
    C-->>S: partial shipment ID
    S->>DB: mark operation succeeded
  end
  opt Delivery enabled
    S->>O: delivery_booking + payload fingerprint
    O->>DB: persist operation revision
    S->>DB: claim operation row
    S->>D: create shipment
    D-->>S: shipment, tracking, and documents
    S->>DB: persist result atomically
  end
```

An operation has a kind, revision, request fingerprint, status, attempt count, and provider identifiers. A succeeded operation is idempotent. An `in_progress` or `unknown` operation cannot be dispatched again. A definitive rejection may create a new revision, but only with a new deliberate attempt and a matching persisted fingerprint.

## Fulfillment states

```mermaid
stateDiagram-v2
  [*] --> unbooked
  unbooked --> booking: operation claimed
  booking --> partial_created: Checkout mutation succeeded
  booking --> booked: Delivery mutation succeeded
  partial_created --> booked: Delivery mutation succeeded
  booking --> rejected: definitive failure
  partial_created --> rejected: definitive failure
  rejected --> booking: corrected retry
  booking --> reconciliation_pending: ambiguous outcome
  partial_created --> reconciliation_pending: ambiguous outcome
  booked --> canceled: cancellation confirmed
  booked --> reconciliation_pending: cancellation outcome unknown
  reconciliation_pending --> booked: booking found
  reconciliation_pending --> canceled: cancellation found
```

Timeouts, connection loss, malformed mutation responses, HTTP 408, and provider 5xx responses are ambiguous once dispatch may have happened. Delivery reconciliation searches shipment history by the persisted merchant reference. It adopts an exact match but never treats “not found” as permission to create another shipment. Checkout partial shipments require manual verification because the adapter has no safe lookup for them.

## Persistence model

```mermaid
erDiagram
  SPREE_STORE ||--o{ CONNECTION : has
  CONNECTION ||--o{ RATE_SELECTION : quotes
  CONNECTION ||--o{ FULFILLMENT : owns
  SPREE_SHIPPING_RATE ||--o| RATE_SELECTION : carries
  SPREE_SHIPMENT ||--o| FULFILLMENT : creates
  RATE_SELECTION ||--o| FULFILLMENT : becomes
  FULFILLMENT ||--o{ OPERATION : records
  FULFILLMENT ||--o{ DOCUMENT : exposes
  FULFILLMENT ||--o{ TRACKING_EVENT : receives
```

Database constraints enforce one selection per shipping rate, one fulfillment per shipment and selection, unique provider resources within a connection, ordered operation revisions, unique document IDs per fulfillment, and idempotent tracking events. Model validations mirror those rules for useful application errors; the database remains the concurrency boundary.

## Post-booking flows

```mermaid
flowchart LR
  Admin["Authorized admin action"]
  Queue["Active Job"]
  Cancel["CancelFulfillment"]
  Reconcile["ReconcileBooking"]
  Documents["RefreshDocuments"]
  Tracking["SyncTracking"]
  Delivery["Delivery client"]
  ShipmentData["Shipment Data client"]
  DB[("Fulfillment records")]

  Admin --> Queue
  Queue --> Cancel --> Delivery
  Queue --> Reconcile --> Delivery
  Queue --> Documents --> Delivery
  Queue --> Tracking --> ShipmentData
  Cancel --> DB
  Reconcile --> DB
  Documents --> DB
  Tracking --> DB
```

- Cancellation uses the same persisted-operation rules as booking.
- Document refresh stores metadata only. The authorized download endpoint validates shipment and document identifiers and serves the provider response without following stored URLs.
- Tracking first locates the shipment by the stable order reference, then upserts events by external ID. Terminal tracking states do not regress.
- Queue failures emit `solidus_nshift.enqueue_failed`. Provider requests emit `solidus_nshift.request`. Neither payload includes credentials, addresses, tokens, label data, or job arguments.

## Configuration seams

`SolidusNshift.configure` exposes the small set of runtime seams needed by host applications and tests:

| Setting | Default | Purpose |
| --- | --- | --- |
| `cache` | `Rails.cache`, then process memory | OAuth token and checkout request caching |
| `transport_factory` | `Http::NetHttpTransport` | HTTP construction and test substitution |
| `parcel_builder` | One parcel from the Solidus package | Merchant-specific parcel grouping |
| `book_shipment_job` | `BookShipmentJob` | Host-specific booking queue class |
| `sync_tracking_job` | `SyncTrackingJob` | Host-specific tracking queue class |
| `clock`, `sleeper`, `logger` | Ruby/Rails defaults | Deterministic time, backoff, and structured logging |
| `rate_cache_ttl` | 300 seconds | Checkout quote cache lifetime |

Production applications with more than one process must replace the memory fallback with a shared cache. Custom parcel builders must return positive weights in kilograms and positive integer copy counts.

## Scope boundaries

This release does not implement manifests, consolidated or return shipments, Shipment Server, Delivery Cloud, dangerous goods, or customs/non-EU shipment data. A service that needs one of those payloads must not be enabled until its contract, fixtures, validation, and test-account evidence have been added.

Continue with the [operations guide](operations.md), [API decision record](adr/0001-nshift-api-products.md), or [migration guide](migration-from-spree-unifaun.md).
