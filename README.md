# Solidus nShift

[![Gem Version](https://img.shields.io/gem/v/solidus_nshift.svg)](https://rubygems.org/gems/solidus_nshift)
[![CI](https://github.com/futhr/solidus_nshift/actions/workflows/ci.yml/badge.svg)](https://github.com/futhr/solidus_nshift/actions/workflows/ci.yml)
[![Codecov](https://codecov.io/gh/futhr/solidus_nshift/graph/badge.svg)](https://codecov.io/gh/futhr/solidus_nshift)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE.md)

`solidus_nshift` adds nShift checkout and fulfillment to Solidus. It keeps provider traffic out of checkout models, records every shipment mutation before dispatch, and gives operators a safe path through uncertain provider outcomes.

## Features

- Checkout sessions, dynamic delivery options, and service points through nShift Checkout v2
- Exact decimal rates with destination and package-context validation
- Delivery booking, cancellation, and PDF or ZPL label download
- Shipment Data lookup and idempotent tracking updates
- Durable operation history, reconciliation, and authorized Solidus admin screens

## Compatibility

| Ruby | Rails | Solidus |
| --- | --- | --- |
| 3.2 | 7.1 | 4.6 |
| 3.3 or 3.4 | 7.2 | 4.7 |

CI runs the suite on SQLite, PostgreSQL 17, and MySQL 8.4. PostgreSQL also runs the row-lock and unique-key concurrency examples.

## Installation

Add the gem to the application:

```ruby
gem "solidus_nshift", ">= 0.1.0.alpha.1", "< 0.2"
```

Install it and copy the migrations:

```sh
bundle install
bin/rails generate solidus_nshift:install
bin/rails db:migrate
```

The generator mounts the engine at `/solidus_nshift` and creates `config/initializers/solidus_nshift.rb`.

Set a stable, high-entropy 32-byte `SOLIDUS_PREFERENCES_MASTER_KEY` before saving credentials. Changing this key makes existing encrypted preferences unreadable.

## Configuration

Open **Admin → nShift → Connections** and create a separate connection for each store and environment. Enable only the nShift products available to that account:

- **Checkout** needs a Portal OAuth client and Checkout connection ID.
- **Delivery** needs API credentials, developer ID, sender Quick ID, sender address, and label settings.
- **Tracking** needs a Shipment Data OAuth client.

Add the `nShift Checkout` calculator to a shipping method, then choose its connection, option kind, service allowlist, units, and language. Use separate shipping methods for customer-visible home and pickup choices.

Delivery reconciliation requires the **REST API Shipment History** entitlement. Multi-process deployments also need a shared `Rails.cache` store for OAuth tokens and rate requests.

## Pickup selection

Pickup options store the points offered for their exact shipment context. Submit the chosen point against the selected rate:

```http
PATCH /solidus_nshift/rate_selections/:id.json
X-Spree-Order-Token: <guest order token>
Content-Type: application/json

{"pickup_point_id":"SE-10001"}
```

The endpoint uses Solidus order authorization and rejects stale, completed, unselected, or unoffered choices.

## Runtime guarantees

- Checkout errors fail closed; the gem never invents a zero, stale, or guessed rate.
- Booking and cancellation are fingerprinted and persisted before the provider request.
- Ambiguous mutations enter reconciliation instead of being sent again blindly.
- Secrets, addresses, tokens, and label bodies are excluded from instrumentation.

## Documentation

- [Architecture and code map](docs/README.md)
- [Operations guide](docs/operations.md)
- [nShift test-account certification](docs/sandbox-certification.md)
- [Migration from `spree_unifaun`](docs/migration-from-spree-unifaun.md)
- [Release process](docs/releasing.md)
- [API product decision](docs/adr/0001-nshift-api-products.md)

## Development

```sh
bin/setup
ruby -S bundle exec rake extension:test_app
ruby -S bundle exec rspec
ruby -S bundle exec rubocop
ruby -S bundle exec rake build
```

Tests use synthetic provider fixtures and no real credentials. nShift does not publish a local sandbox for these APIs, so each enabled product still needs a final run with an nShift-provisioned test account.

See [CONTRIBUTING.md](CONTRIBUTING.md) before changing a provider contract, and report vulnerabilities through [SECURITY.md](SECURITY.md).

## License

Released under the [BSD 3-Clause License](LICENSE.md).
