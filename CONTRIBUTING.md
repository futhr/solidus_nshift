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

## PostgreSQL 18.6 and local validation

The PostgreSQL baseline is 18.6 with `pg` 1.6.3 or later in the 1.6 series.
Build the source gem against PostgreSQL 18.6/libpq 18.6. On Debian 12 or Ubuntu
24.04, `bin/setup-postgresql-client` installs the pinned PGDG client. On macOS,
use `brew install postgresql@18` and set `BUNDLE_BUILD__PG` to
`--with-pg-config=$(brew --prefix postgresql@18)/bin/pg_config`.

Set `DB=postgresql`, `DB_HOST`, `PGPORT`, `DB_USERNAME`, and `DB_PASSWORD`
before `bundle install` and regenerating the dummy application. Run the full
RSpec suite, eager-loading check, style, audit, and package checks locally.
Use an isolated test database; the dummy generator creates and migrates it.
Verify `PG.library_version` and the server's `server_version_num` are `180006`.

The automatic PR workflow uses one PostgreSQL 18.6 lane and one coverage run.
Additional Ruby/Rails and database profiles are explicit manual `full_matrix`
checks. Run them locally for affected compatibility changes; do not dispatch
Actions to iterate on failures. There are no duplicate push or scheduled test
runs.
