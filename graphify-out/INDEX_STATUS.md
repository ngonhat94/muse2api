# Graph index status

Updated at: 2026-11-15 (UTC)

- Graph includes the uncommitted working tree, including untracked Flutter files.
- Refreshed incrementally after the secure multi-tenant backend, admin console, protected-media Flutter transport, cancellation, and verification changes, then re-clustered without LLM labeling.
- Stored graph: 3232 nodes, 6001 edges, 191 communities across 289 represented files.
- Backend `app.py`, `engine.py`, `store.py`, `tenant.py`, `proxy.py` and tests are indexed.
- Desktop anchors: DesktopEngine, ProcessDesktopEngine, ConnectionBloc, LocalEnginePanel, DesktopEngineFailure, DesktopEngineInstaller, ProcessDesktopInstaller, desktop/launcher.py and tools/run_desktop.py.
- Multi-tenant anchors: UserStore, Store, `_owner`, AccountPoolManager, protected media capability helpers, ServerPrincipal, ServerConnection, task cancellation, and media repositories. Existing chat, generation, credential, cookie import and dependency sources remain indexed.
- Source extraction uses AST/code only; no LLM extraction or remote upload was performed. Existing semantic nodes were preserved; newly changed prose and images were not semantically re-indexed.
- Ignored: build/cache directories, installed skills, generated plugin registrants, platform icon assets, and VCS-ignored runtime data/credentials.
- Extractor limitations: 63 unsupported-format files (primarily platform XML/config) were skipped. Community labels are structural and may retain older names until an LLM labeling pass.
- Existing community labels are retained where possible; changed communities use structural hub names. Labels are navigation hints, not model-inferred behavior.

## Refresh after editing

Run from the repository root:

```bash
graphify update .
```

Build exclusions and code-only scope are persisted in `.graphify_build.json`.
The AST manifest tracks source content; do not rely solely on HEAD because the Flutter project is currently untracked.
For an explicit reproducible extraction without community-labeling calls:

```bash
graphify extract . --code-only --no-cluster --no-dedup --max-workers 4
graphify cluster-only . --no-label
```

Do not add credentials, runtime accounts, media or dependency caches to the corpus.
