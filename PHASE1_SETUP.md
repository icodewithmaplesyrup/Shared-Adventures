# Shared Adventures — Phase 1 Vertical Slice

This phase wires the existing POC UI to a real Supabase backend so one real postcard can route to one real stranger.

## 1) Create Supabase project
1. Create a Supabase project.
2. Run `supabase/schema.sql` in the SQL editor.
3. Copy your project URL and anon key.

## 2) Configure the PWA page
Before opening `Static-POC.html`, define credentials in DevTools console (or inject them in a script tag):

```js
localStorage.setItem('supabase_url', 'https://YOUR_PROJECT.supabase.co');
localStorage.setItem('supabase_anon_key', 'YOUR_PUBLIC_ANON_KEY');
location.reload();
```

## 3) Phase 1 flow
1. Go to **YOUR DOOR** and save door text + city.
2. Go to **WRITE**, compose a postcard, and send.
3. Backend uses `match_recipient_for_sender(...)` to pick one recipient from semantic ranks 5-100.

## Matching behavior in SQL
- Uses `pgvector` cosine distance (`<=>`).
- Avoids sender itself.
- Avoids users who already received a postcard.
- Avoids repeat pairs in either direction.
- Samples randomly from ranks **5..100** to avoid near-duplicate matching.
