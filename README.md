# Solidus nShift

[![Gem Version](https://img.shields.io/gem/v/solidus_nshift.svg)](https://rubygems.org/gems/solidus_nshift)
[![CI](https://github.com/futhr/solidus_nshift/actions/workflows/ci.yml/badge.svg)](https://github.com/futhr/solidus_nshift/actions/workflows/ci.yml)
[![Codecov](https://codecov.io/gh/futhr/solidus_nshift/graph/badge.svg)](https://codecov.io/gh/futhr/solidus_nshift)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE.md)

`solidus_nshift` adds nShift delivery options, pickup points, booking, labels, and tracking to Solidus. Shipment requests are recorded before they are sent, so a timeout can be investigated without accidentally booking twice.

This is an unreleased alpha. Automated tests use synthetic responses; production use still requires the [nShift test-account checks](docs/sandbox-certification.md).

## Features

- Checkout sessions, dynamic delivery options, and service points through nShift Checkout v2
- Exact decimal rates with destination and package-context validation
- Delivery booking, cancellation, and PDF or ZPL label download
- Shipment Data lookup and idempotent tracking updates
- Durable operation history, reconciliation, and authorized Solidus admin screens

## Compatibility

| Ruby | Rails | Solidus |
| --- | --- | --- |
| 3.3 or 3.4 | 8.1 | 4.7 |
| 3.2 (legacy compatibility) | 7.2 | 4.6 |

CI covers SQLite, PostgreSQL 17, and MySQL 8.4, including PostgreSQL concurrency tests. New applications should use Ruby 3.3+ and Rails 8.1; the older row is a compatibility check, not an upstream support commitment. Ruby 3.2 and Rails 7.2 have reached the end of their published support periods. See the [Ruby branches](https://www.ruby-lang.org/en/downloads/branches/) and [Rails maintenance policy](https://guides.rubyonrails.org/maintenance_policy.html).

The admin screens require `solidus_backend`. Core-only stores can use the services and pickup endpoint, but need to provide their own admin UI. `solidus_admin` screens are not included.

## Installation

Until the first RubyGems publication, use a local checkout in the application:

```ruby
gem "solidus_nshift", path: "../solidus_nshift"
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

## Failure handling

- Checkout errors fail closed; the gem never invents a zero, stale, or guessed rate.
- Booking and cancellation are fingerprinted and persisted before the provider request.
- Ambiguous mutations enter reconciliation instead of being sent again blindly.
- Request notifications contain operation identifiers and error classes, without exception objects or provider error messages.

## Documentation

- [Architecture and code map](docs/README.md)
- [Operations guide](docs/operations.md)
- [nShift test-account certification](docs/sandbox-certification.md)
- [Migration from `spree_unifaun`](docs/migration-from-spree-unifaun.md)
- [Release process](docs/releasing.md)
- [September 2026 audit and remaining checks](docs/audit-2026-09-06.md)
- [API product decision](docs/adr/0001-nshift-api-products.md)

## Development

```sh
bin/setup
bundle exec rake extension:test_app
bundle exec rspec
bundle exec rubocop
bundle exec rake build
ruby bin/check_package
```

Tests block outbound network calls and use synthetic fixtures. See [CONTRIBUTING.md](CONTRIBUTING.md) for dependency audits and alternative compatibility bundles.

See [CONTRIBUTING.md](CONTRIBUTING.md) before changing a provider contract, and report vulnerabilities through [SECURITY.md](SECURITY.md).

## License

Released under the [BSD 3-Clause License](LICENSE.md).
