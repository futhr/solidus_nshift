# Releasing the gem

The repository is prepared for an alpha release. Building or checking a package does not tag, push, or publish it. Production certification and publisher configuration are separate checks.

## Local rehearsal

```sh
bundle install
bundle exec rake extension:test_app
bundle exec rspec
bundle exec rubocop
bundle exec rake build
ruby bin/check_package
BUNDLE_GEMFILE=gemfiles/runtime_audit.gemfile bundle update
bundle-audit check --gemfile-lock gemfiles/runtime_audit.gemfile.lock --update
```

`check_package` verifies the archive, version, license, MFA metadata, required code and migrations, and unexpected files. It prints a SHA256 checksum. Inspect the packaged documentation as well as the source checkout. Keep the version unchanged while rehearsing an unpublished release.

Run the CI matrix and the [nShift test-account checklist](sandbox-certification.md) before claiming production readiness. The development-only Puma audit limitation is recorded in [SECURITY.md](../SECURITY.md).

## Publisher and GitHub settings

Publishing uses [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/), with a short-lived OIDC token. Configure a trusted publisher, or a pending publisher for a new gem, with owner `futhr`, repository `solidus_nshift`, workflow `release.yml`, and environment `release`.

Before a release, verify:

- The `release` environment requires maintainer approval, disallows administrator bypass, and permits only `v*` tags.
- The default branch requires the current CI jobs and reviewed pull requests, and prevents force pushes and deletion.
- The `v*` tag ruleset prevents tag updates and deletion.

These are account settings; this runbook does not establish that they are enabled. The September 6, 2026 read-only review found active history, PR-review and immutable-tag rulesets, but no required CI status checks. The PR-review rule also permits a maintainer bypass. Configure the intended requirements before publishing. Repository visibility is always a manual, user-only setting.

Useful read-only checks:

```sh
gh api repos/futhr/solidus_nshift/environments/release
gh api repos/futhr/solidus_nshift/environments/release/deployment-branch-policies
gh api repos/futhr/solidus_nshift/rulesets
# Inspect each returned ruleset with: gh api repos/futhr/solidus_nshift/rulesets/ID
```

## Publishing later

When the checks above pass, finalize the version and date in `CHANGELOG.md`, commit the release, and merge it to `main`. After CI passes, a maintainer can create and push an annotated tag matching `vVERSION`.

The release workflow verifies that the tag matches the Ruby version constant and points to a commit on `main`. It reruns tests, lint, package checks and the runtime dependency audit before publishing. Its GitHub token cannot write repository contents. Never move or reuse a published tag.
