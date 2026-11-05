# Repository instructions

Read [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md),
[SECURITY.md](SECURITY.md) and the owning delivery contract before changing
behavior. Preserve unrelated work and machine-local settings. Never push Git
refs or change repository visibility. Provider booking, cancellation, credentials
and release operations need their actual task authorization.

## Skills and discovery

Keep shared skills under tracked `.agents/skills/<name>/SKILL.md`. Choose them
automatically from task/mechanism descriptions and read the selected instructions
before proceeding. Keep implicit invocation enabled; users do not invoke skills
manually. [security-review](.agents/skills/security-review/SKILL.md) handles
requested security audits and changes to OAuth, shipment ownership, downloads,
credentials or uncertain external effects, rather than routine label styling.

Codex reads `.agents/skills` natively. Other clients must inspect descriptions
and read matching bodies when native discovery is absent. Claude discovery uses
ignored individual `.claude/skills/<name>` directory symlinks to
`../../.agents/skills/<name>`. Preserve unrelated entries and settings; repair
repository-owned links only. Do not introduce client hooks or wrappers.

Validate guidance through existing frontmatter, reference, tracking/ignore,
discovery and semantic checks without gem installation or store/provider startup.
Select runtime checks from CONTRIBUTING when application behavior changes.
Fixtures, an actual nShift test account and carrier/device qualification support
different claims; report the evidence actually obtained.
