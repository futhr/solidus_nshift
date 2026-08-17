# Contributing

Use Ruby 3.2+ and never put real nShift credentials, labels, addresses, tracking numbers, or customer data in tests.

```sh
bin/setup
ruby -S bundle exec rake extension:test_app
ruby -S bundle exec rspec
ruby -S bundle exec rubocop
ruby -S bundle exec rake build
```

Changes to provider contracts require:

- an official nShift source linked from the relevant ADR or documentation;
- a sanitized synthetic fixture for every new response shape;
- typed error behavior for authentication, validation, rate limit, unavailable, malformed, and ambiguous mutation responses;
- tests proving that retries cannot duplicate a provider mutation;
- documentation for any new account entitlement or operational recovery step.

Keep commits narrowly focused and use Conventional Commit subjects. Do not add compatibility aliases for the retired `spree_unifaun` namespace.

Maintainers should follow the [release runbook](docs/releasing.md); releases use RubyGems trusted publishing and never a stored API token.
