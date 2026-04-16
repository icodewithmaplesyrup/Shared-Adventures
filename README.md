# Shared Adventures

Shared Adventures is a static HTML prototype for writing and routing "postcards" between anonymous users based on semantic similarity of each user's "door" story.

The project currently focuses on a **Phase 1 vertical slice**:
- Static browser UI (no custom backend server)
- Supabase as database + API
- `pgvector`-based matching for postcard recipients

## Project Structure

- `Static-POC.html` — main static prototype page wired to Supabase.
- `smallmatch.html` and `HeavyMatch.html` — matching-related prototype variants.
- `supabase/schema.sql` — schema + matching SQL function (`match_recipient_for_sender`).
- `PHASE1_SETUP.md` — full end-to-end setup and verification guide.

## Quick Start

### 1) Create and configure Supabase

1. Create a new Supabase project.
2. Open `supabase/schema.sql` and run the full script in Supabase SQL Editor.
3. Copy your **Project URL** and **anon/public API key** from Supabase settings.

### 2) Run the static app locally

From the repository root:

```bash
python3 -m http.server 8080
```

Open:

- `http://localhost:8080/Static-POC.html`

### 3) Provide credentials in browser DevTools

Run in the console:

```js
localStorage.setItem('supabase_url', 'https://YOUR_PROJECT.supabase.co');
localStorage.setItem('supabase_anon_key', 'YOUR_PUBLIC_ANON_KEY');
location.reload();
```

## How Matching Works (Phase 1)

The `match_recipient_for_sender(uuid)` SQL function:
- excludes the sender,
- avoids repeat pairings in either direction,
- prefers recipients who have not received a postcard yet,
- falls back to any eligible recipient once everyone has received,
- ranks users by cosine distance on `door_vector`,
- prefers semantic ranks **5..100** when enough candidates exist,
- falls back to ranks **1..100** for tiny datasets.

## Notes

- This is prototype-mode setup: row-level security is currently disabled in `schema.sql`.
- For realistic matching tests, seed at least 6 users.
- See `PHASE1_SETUP.md` for full details and troubleshooting steps.
