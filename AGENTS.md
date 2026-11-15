# muse2api

- Flutter client lives in `muse_app/`; keep BLoC and Clean Architecture with domain, data and presentation separated by feature.
- For frontend work, use the user-requested UI UX Pro Max, Taste and Impeccable skills. Read their current instructions before applying them. UI UX Pro Max is at `muse_app/.agents/skills/ui-ux-pro-max/SKILL.md`; discover Taste from the installed `taste-skill` plugin and Impeccable from the available skill catalog.
- Apply the skills to the actual Flutter app and preserve its working flows; website-only HTML/marketing mechanics should not replace native widgets.
- Preserve remembered server credentials; never log API keys or Muse cookies.
- Verify with analysis, relevant tests, and a build. Distinguish simulated verification from real Muse/device testing.

## Code graph

- Reuse `graphify-out/graph.json` for architecture, symbol relationships and impact analysis; read `graphify-out/INDEX_STATUS.md` for scope and parser limitations.
- The graph includes uncommitted Flutter code. Check the source/AST manifest for freshness; matching git HEAD alone is insufficient.
- Refresh with `graphify update .` from this repository root after meaningful code changes. Keep the persisted build exclusions for generated files, caches and installed skills.
- Read current source before editing; the graph does not replace source verification, tests or builds.
