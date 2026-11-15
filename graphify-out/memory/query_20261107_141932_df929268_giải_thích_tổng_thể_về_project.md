---
type: "query"
date: "2026-11-07T14:19:32.041717+00:00"
question: "giải thích tổng thể về project"
contributor: "graphify"
outcome: "useful"
source_nodes: ["MuseEngine", "Store", "Config", "CDP", "create_image_task", "create_video", "resolve_model"]
---

# Q: giải thích tổng thể về project

## Answer

Expanded from original query via vocab: [app, engine, cdp, store, proxy, account, chat, generation, task, session, config]. muse2api exposes OpenAI-compatible chat/completions, responses, images and video endpoints via FastAPI app.py. app.py imports MuseEngine (engine.py:L298), Store (store.py:L99) and Config (config.py:L66). MuseEngine automates Chromium through CDP (cdp.py:L17); generate (engine.py:L1783) calls ensure_page, reset_thread, attachment preparation and _generate_attached. Store persists accounts and tasks as JSON and selects warm accounts with rotation. app.py:L92 limits concurrency and L133 leases accounts exclusively. Chat uses chat_stream (engine.py:L1433) and SSE adaptation. Image tasks (app.py:L1322) use background workers, polling and idempotency; video tasks start at app.py:L1463. Admin UI and extension support account import and operations. Proxy routing is per account. Model aliases resolve to Muse capabilities rather than the named external provider. Current source was checked; graph built_at_commit matches HEAD. No live generation or tests were run.

## Outcome

- Signal: useful

## Source Nodes

- MuseEngine
- Store
- Config
- CDP
- create_image_task
- create_video
- resolve_model