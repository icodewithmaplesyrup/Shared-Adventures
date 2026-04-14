# Shared Adventures — Phase 1 Vertical Slice Setup

This guide is intentionally end-to-end for a **brand-new Supabase project** and a local copy of this repo.

The UI remains a **static HTML POC**. "Static" here means no custom app server — the page talks directly to Supabase over HTTPS.

---

## Prerequisites
1. A Supabase account.
2. A local clone/download of this repository (so you actually have `Static-POC.html` and `supabase/schema.sql`).
3. A modern browser (Chrome/Safari/Edge) with DevTools.
4. A lightweight local static server (Python works: `python3 -m http.server`).

If you do **not** have this repo locally yet, start here (or download the repo ZIP and extract it):

```bash
git clone <your-fork-or-repo-url>
cd Shared-Adventures
```

---

## 1) Create the Supabase project
1. In Supabase, click **New project**.
2. Choose organization, project name, database password, and region.
3. Wait for provisioning to complete.

---

## 2) Apply the DB schema from this repo
1. In your local repo, open `supabase/schema.sql`.
2. Copy the **entire file contents**.
3. In Supabase dashboard, go to **SQL Editor** → **New query**.
4. Paste the SQL and click **Run**.
5. Confirm success:
   - `users` and `postcards` tables exist.
   - `match_recipient_for_sender(uuid)` exists.

---

## 3) Get your Supabase credentials
In Supabase dashboard:
1. Go to **Project Settings** → **API**.
2. Copy:
   - **Project URL**
   - **Project API key (anon/public)**

---

## 4) Serve the static app over localhost (required)
Do **not** open the file via `file://.../Static-POC.html`.

From the repo root, run:

```bash
python3 -m http.server 8080
```

Then open:

- `http://localhost:8080/Static-POC.html`

## 5) Configure the POC page with credentials
Open `http://localhost:8080/Static-POC.html` and run this in DevTools Console:

```js
localStorage.setItem('supabase_url', 'https://YOUR_PROJECT.supabase.co');
localStorage.setItem('supabase_anon_key', 'YOUR_PUBLIC_ANON_KEY');
location.reload();
```

> Alternative: set `window.SUPABASE_URL` and `window.SUPABASE_ANON_KEY` before the app script runs.

---

## 6) Seed users for routing tests
The matcher prefers ranks **5..100** to avoid near-duplicate matches.
For small datasets, it now automatically falls back to ranks **1..100** so early testing still works.

Recommended for realistic behavior: **6+ users**.
Minimum to prove end-to-end send path: **2 users**.

Quick ways to create test users:
- Open the app in multiple browser profiles/incognito sessions.
- In each session, complete **YOUR DOOR** with a unique story + city.

---

## 7) Run the Phase 1 happy path
1. In one session, open **YOUR DOOR** and submit door text + city.
2. Go to **WRITE**, enter postcard body (image optional), send.
3. The app will:
   - embed your door text client-side (`all-MiniLM-L6-v2`),
   - upsert your user row,
   - call `match_recipient_for_sender`,
   - insert one row into `postcards`.

---

## 8) Verify in Supabase (recommended)
In **Table Editor**:
- `users` should contain your anon id, city, door text, and vector.
- `postcards` should contain one new row with `from_id`, `to_id`, `body`, and `status='sent'`.

---

## Known prototype constraints (expected in Phase 1)
- RLS is disabled in `schema.sql` for speed of prototyping.
- Inbox/route views are still mostly static UI.
- No moderation pipeline yet.

## Matching behavior
- Cosine distance via pgvector (`<=>`).
- Excludes sender.
- Avoids repeat pairings in either direction.
- Avoids users who already received a postcard.
- Prefers semantic ranks **5..100** (and falls back to **1..100** when candidate count is <5).
