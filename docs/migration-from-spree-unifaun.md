# Migration from spree-unifaun

This is a breaking replacement, not an in-place namespace upgrade.

## Renames

| Legacy | Current |
| --- | --- |
| gem/repository `spree-unifaun` | `solidus_nshift` |
| legacy Spree/Unifaun constants | `SolidusNshift` |
| static carrier CSV/import code | live nShift Checkout option normalization |
| legacy calculator/service classes | `Spree::Calculator::Shipping::NshiftCheckout` |
| historical Unifaun endpoints | separate current Checkout, Delivery, and Shipment Data clients |

No compatibility aliases are provided. This prevents old constants, credentials, or endpoint assumptions from silently operating in a modern store.

## Required migration

1. Remove the old gem and add `solidus_nshift`.
2. Run `bin/rails generate solidus_nshift:install` and migrate.
3. Set `SOLIDUS_PREFERENCES_MASTER_KEY` to a stable 32-byte secret.
4. Create new per-store nShift connections. Legacy plaintext/settings data is intentionally not imported.
5. Replace each old shipping method/calculator with one or more nShift Checkout shipping methods. Use separate `home` and `pickup` methods where both are displayed.
6. Enter the complete sender address and validate it, every allowed nShift service code, and the sender Quick ID in a test account.
7. Complete the [nShift test-account certification](sandbox-certification.md) before enabling production credentials.

Existing completed legacy shipments remain historical Solidus data and receive no synthetic nShift fulfillment rows. In-progress checkouts must be re-rated after the new shipping methods are active.

The certification record is the release gate. Keep test and production connections separate, and leave Delivery test mode on until production cutover.
