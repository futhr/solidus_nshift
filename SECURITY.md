# Security policy

## Reporting

Report suspected vulnerabilities privately to `hi@futhr.io`. Do not open a public issue containing credentials, customer data, provider responses, or exploit details.

## Supported versions

Until the first stable release, only the latest published prerelease receives security fixes.

## Credential and data handling

- Set `SOLIDUS_PREFERENCES_MASTER_KEY` to a stable, high-entropy 32-byte value outside source control.
- Give nShift credentials only the products and environments they require.
- Keep test and production connection records separate.
- Restrict Solidus admin access and production job/log access.
- Do not log request bodies, OAuth tokens, API keys, addresses, label binaries, or customer contact data.
- Rotate exposed credentials in nShift first, then update the connection. Blank admin secret fields intentionally retain stored values.
- Publish releases through the trusted-publishing workflow; never store a RubyGems API key in the repository or GitHub Actions.

Label download and fulfillment actions inherit Solidus admin authorization. Pickup selection inherits Solidus order authorization and checks that the submitted point belongs to the selected rate and incomplete order.

## Development dependency advisories

As of September 6, 2026, `solidus_dev_support` 2.12.0 requires Puma below 7. The resulting Puma 6.6.1 has two open advisories: [CVE-2026-47736](https://github.com/puma/puma/security/advisories/GHSA-qpgp-93vx-g8v8) and [CVE-2026-47737](https://github.com/puma/puma/security/advisories/GHSA-2vqw-3mp8-cgmx). The fixed versions are incompatible with that development dependency constraint.

Puma is not a runtime dependency of this gem. Do not expose the dummy application's server publicly or enable PROXY protocol in it. CI audits the runtime bundle as a required check and reports the development audit separately without suppressing advisory IDs. Update the development harness when upstream permits a fixed Puma version; until then, the full development bundle does not have a clean security audit.
