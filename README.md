# Solidus nShift

`solidus_nshift` connects Solidus 4.6+ to the current nShift product families without carrying the old `spree_unifaun` API or namespace forward.

It provides:

- nShift Checkout v2 OAuth, sessions, dynamic shipping options, and partial shipments;
- exact decimal rates and service-point continuity through Solidus checkout;
- nShift Delivery REST shipment booking, PDF/ZPL document references, download, and cancellation;
- Shipment Data OAuth lookup and idempotent tracking-event synchronization;
- durable operation intents and reconciliation after ambiguous network outcomes;
- authorized Solidus admin screens for credentials and fulfillment operations.

## Compatibility

- Ruby 3.2 or newer
- Solidus 4.6 or 4.7
- Rails 7.1 or 7.2

The CI matrix verifies the minimum and current supported combinations. The gem uses `SolidusNshift` as its Ruby namespace and `solidus_nshift` for gem, engine, table, route, and instrumentation identities.

## Installation

Add the gem to the Solidus application:

```ruby
gem "solidus_nshift", github: "futhr/solidus_nshift"
```

Then install and migrate:

```sh
bundle install
bin/rails generate solidus_nshift:install
bin/rails db:migrate
```

The installer mounts the isolated engine at `/solidus_nshift`, copies migrations, and creates `config/initializers/solidus_nshift.rb`.

Set a 32-byte `SOLIDUS_PREFERENCES_MASTER_KEY` in every environment before configuring encrypted nShift credentials. Changing this key makes stored secrets unreadable.

## Configuration

Open **Admin → nShift → Connections** and create a connection for each Solidus store/environment. Test and production credentials must use separate records.

Enable only the capabilities licensed for that nShift account:

- **Checkout:** Portal OAuth client ID/secret and Checkout connection ID.
- **Delivery:** API key ID/secret, developer ID, and sender Quick ID.
- **Tracking:** Shipment Data OAuth client ID/secret.

Secret fields are never echoed back by the admin form. Submitting a blank secret retains the encrypted stored value.

Create one `Spree::ShippingMethod` per customer-visible option family and select the `nShift Checkout` calculator. Configure:

- the connection ID;
- optional allowed nShift service codes, separated by commas or whitespace;
- option kind: `home`, `pickup`, or `any`;
- Solidus weight/dimension units and two-letter nShift language code.

Solidus persists one rate per shipping method and shipment. Separate home/pickup shipping methods preserve that invariant while a shared request cache prevents duplicate nShift calls.

Checkout failures are fail-closed: an authentication, transport, schema, currency, or provider error yields no nShift rate. Other independently configured Solidus shipping methods remain available, which is the supported explicit fallback. The gem never substitutes a stale, zero, or guessed nShift rate.

## Pickup selection

The selected `Spree::ShippingRate` has a `nshift_selection` containing the current session, opaque option ID, context digest, and offered points. A storefront selects a point with:

```http
PATCH /solidus_nshift/rate_selections/:id.json
X-Spree-Order-Token: <order guest token>
Content-Type: application/json

{"pickup_point_id":"SE-10001"}
```

The endpoint uses Solidus authorization, accepts only a point returned for the selected rate, and rejects completed orders. Changing destination, package, connection, or session invalidates the old selection.

## Fulfillment behavior

`order_finalized` enqueues a booking job only for shipments with a selected nShift rate. Booking is never performed by the estimator or an Active Record callback.

Before any provider mutation, the gem persists a unique fulfillment intent and a SHA-256 fingerprinted operation. Checkout partial-shipment creation and Delivery booking are separate operations. Concurrent or repeated jobs cannot dispatch a succeeded/in-progress operation twice.

When a mutating request times out or returns an ambiguous response, the operation becomes `unknown` and the fulfillment becomes `reconciliation_pending`. Delivery reconciliation searches by the stable merchant reference and adopts a found shipment. It never assumes “not found” is permission to create another shipment. Checkout partial-shipment ambiguity requires manual provider verification because that API does not expose a safe lookup in this adapter.

See [Operations](docs/operations.md), [API decision ADR](docs/adr/0001-nshift-api-products.md), and [migration guide](docs/migration-from-spree-unifaun.md).

## Development

```sh
bin/setup
ruby -S bundle exec rake extension:test_app
ruby -S bundle exec rspec
ruby -S bundle exec rubocop
ruby -S bundle exec rake build
```

Provider tests use sanitized synthetic fixtures and never require production credentials. A real nShift test-account certification run remains mandatory before enabling a capability in production.

Manifests, consolidated shipments, Shipment Server, Delivery Cloud, dangerous-goods handling, and customs/non-EU shipment data are outside this release. Do not enable a service that requires those payloads without adding and certifying the corresponding adapter behavior.

## License

BSD-3-Clause. See [LICENSE.md](LICENSE.md).
