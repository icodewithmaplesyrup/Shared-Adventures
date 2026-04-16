# Phase 2 Plan — Core Loop Completion

This document captures the agreed implementation plan for Phase 2 after completing the Phase 1 vertical slice.

## Goal
Complete the full postcard lifecycle so a real postcard can be:
1. Received in inbox from the database.
2. Replied to (back to sender).
3. Passed along to a new matched stranger.
4. Viewed as part of a real route chain/history.

## Proposed Scope

### 1) Data model upgrades
Extend `postcards` with relationship and lifecycle fields:
- `parent_postcard_id` (nullable): links reply/pass-along cards to their source card.
- `root_postcard_id`: anchor for route chain queries.
- `route_depth`: hop number, with `0` as original postcard.
- `routed_by`: indicates routing basis (`door` now; extensible to `reply`).
- lifecycle timestamps such as `read_at`, `replied_at`, `passed_at`.

Optional audit table for event history:
- `postcard_events(postcard_id, event_type, actor_id, to_id, created_at, meta)`.

### 2) Matching semantics
- **Reply:** direct return to original sender (`to_id = parent.from_id`).
- **Pass Along:** route to a new stranger via matching RPC.
- Phase 2 default: use reply/pass body embedding for pass-along routing while preserving sender constraints.

### 3) Backend RPC/functions
Add SQL functions to keep route mutations atomic:
- `send_postcard(...)`
- `reply_postcard(parent_postcard_id, ...)`
- `pass_postcard(parent_postcard_id, ...)`
- `get_inbox(user_id)`
- `get_route(root_postcard_id)`

### 4) Frontend integration (`Static-POC.html`)
- Inbox renders only DB-backed rows.
- Compose gains explicit modes: `new`, `reply`, `pass`.
- Reply and Pass Along actions route through corresponding backend functions.
- Route tab renders ordered chain from `get_route`.

### 5) Lightweight notifications
- Poll inbox periodically while app is open (e.g., every 20–30s).
- Show in-app badge/indicator for newly arrived postcards.

## Recommended Build Order
1. Schema + RPC migration.
2. Inbox query/render cleanup.
3. Reply flow.
4. Pass-along flow.
5. Route chain rendering.
6. Polling + new-mail indicator.

## Acceptance Criteria
Phase 2 is complete when all are true:
- Inbox displays real DB postcards without hardcoded cards.
- Reply creates a linked child postcard that routes back correctly.
- Pass Along creates a new hop to an eligible stranger.
- Route view shows full real chain with timestamps and cities.
- No placeholder sample route content remains in active flows.
