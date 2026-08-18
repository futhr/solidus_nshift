# Releasing the gem

Releases are built from `main` and published by GitHub Actions with RubyGems trusted publishing. The workflow uses a short-lived OpenID Connect token; do not create or store a RubyGems API key.
Its GitHub token is read-only: maintainers create the protected tag before the workflow starts, and the publishing job cannot move that tag or write repository contents.

## One-time setup

1. Create a GitHub environment named `release`, disable administrator bypass, require a maintainer's approval, and allow deployments only from tags matching `v*`.
2. In RubyGems.org, create a trusted publisher (or pending trusted publisher for the first release) with:
   - repository owner: `futhr`
   - repository: `solidus_nshift`
   - workflow: `release.yml`
   - environment: `release`
3. Protect `main` for administrators and require every CI job before merging. Require the branch to be current, disable force pushes and deletion, and require linear history.
4. Add an active tag ruleset for `v*` that forbids tag updates, non-fast-forward changes, and deletion.

The canonical repository keeps all four controls enabled. They live in GitHub and RubyGems settings rather than Git, so verify them before each release:

```sh
gh api repos/futhr/solidus_nshift/environments/release
gh api repos/futhr/solidus_nshift/environments/release/deployment-branch-policies
gh api repos/futhr/solidus_nshift/branches/main/protection
gh api repos/futhr/solidus_nshift/rulesets
```

## Release

1. Update `SolidusNshift::VERSION` and move the release notes in `CHANGELOG.md` under the same version and date.
2. Run the normal test, lint, audit, and build checks. Inspect the generated gem before publishing. A local `bundle exec rake build` is the non-publishing release rehearsal.
3. Commit the release as `chore: release vVERSION` and merge it to `main`.
4. After CI passes, create and push an annotated `vVERSION` tag from that commit.

The release workflow checks that the tag matches the Ruby version constant, runs the suite again, builds the gem, and publishes it to RubyGems.org. Never move or reuse a published tag; release a new version for corrections.
