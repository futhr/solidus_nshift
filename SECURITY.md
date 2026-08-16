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

Label download and fulfillment actions inherit Solidus admin authorization. Pickup selection inherits Solidus order authorization and checks that the submitted point belongs to the selected rate and incomplete order.
