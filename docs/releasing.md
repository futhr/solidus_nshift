# Releasing the gem

Releases are built from `main` and published by GitHub Actions with RubyGems trusted publishing. The workflow uses a short-lived OpenID Connect token; do not create or store a RubyGems API key.

## One-time setup

1. Create a GitHub environment named `release` and require a maintainer's approval.
2. In RubyGems.org, create a trusted publisher (or pending trusted publisher for the first release) with:
   - repository owner: `futhr`
   - repository: `solidus_nshift`
   - workflow: `release.yml`
   - environment: `release`
3. Protect `main` and require the CI jobs before merging.

## Release

1. Update `SolidusNshift::VERSION` and move the release notes in `CHANGELOG.md` under the same version and date.
2. Run the normal test, lint, audit, and build checks. Inspect the generated gem before publishing.
3. Commit the release as `chore: release vVERSION` and merge it to `main`.
4. After CI passes, create and push an annotated `vVERSION` tag from that commit.

The release workflow checks that the tag matches the Ruby version constant, runs the suite again, builds the gem, and publishes it to RubyGems.org. Never move or reuse a published tag; release a new version for corrections.
