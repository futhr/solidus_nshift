# Contributing

Use Ruby 3.3 or 3.4 for development, with Node.js available for the legacy backend assets. The default bundle uses published Solidus 4.7 and Rails 8.1. Tests must use synthetic credentials, addresses and labels; outbound network calls are disabled.

```sh
bin/setup
bundle exec rake extension:test_app
bundle exec rspec
bundle exec rubocop
bundle exec rake build
ruby bin/check_package
```

For the legacy compatibility run, set `SOLIDUS_VERSION=4.6` and `RAILS_VERSION=7.2` before installing and generating the dummy application. `SOLIDUS_BRANCH` is available for testing an upstream Git branch. Regenerate `spec/dummy` when changing Rails versions.

The runtime bundle is audited separately from development tools:

```sh
BUNDLE_GEMFILE=gemfiles/runtime_audit.gemfile bundle update
gem install bundler-audit
bundle-audit check --gemfile-lock gemfiles/runtime_audit.gemfile.lock --update
```

Run `bundle outdated` and `bundle-audit check --update` for the full development bundle too. The released `solidus_dev_support` currently pins a Puma version with known advisories; see [SECURITY.md](SECURITY.md). Do not treat a clean runtime audit as a clean development audit.

To check an application without the legacy backend:

```sh
BUNDLE_GEMFILE=gemfiles/core.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/core.gemfile ruby bin/check_core
```

Provider contract changes need an official nShift source, a synthetic fixture, and tests for the new response shape and failure paths. Mutation changes must demonstrate that ambiguous outcomes cannot cause duplicate dispatches. Document any account entitlement or recovery step that operators need.

Use focused Conventional Commits. Avoid speculative abstractions, compatibility aliases for `spree_unifaun`, and tests that only repeat the implementation. Follow the [release runbook](docs/releasing.md) for packaging and publishing.
