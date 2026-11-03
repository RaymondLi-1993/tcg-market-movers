-- Create push_tokens: one row = one device that can receive pushes (a destination, not a push).
-- A user can have many devices (one user → many push tokens).
-- Behavior (enforced in the API/worker, see CLAUDE.md "Data model summary"):
--   - upsert on app open + push tap (match on token, refresh last_seen_at)
--   - if a different user signs in on the same device, the row moves to them
--   - deleted on sign-out, and when Expo reports "device not registered"
--   - cleaned up after 30 days without being seen

-- migrate:up

create table push_tokens (
  -- Its own ID. gen_random_uuid() fills it in automatically.
  id            uuid primary key default gen_random_uuid(),

  -- The Expo push token, e.g. 'ExponentPushToken[xk3J…]'. Identifies "this app on this phone".
  --   unique → one device = one row. The API's upsert matches on this column
  --            ("insert, or update if this token already exists").
  token         text not null unique,

  -- Whose device this is right now (reassigned if another user signs in on it).
  --   on delete cascade → deleting the user deletes their tokens (Story 6, hard delete)
  user_id       uuid not null references auth.users(id) on delete cascade,

  -- Last time we saw this device (app open or push tap). Used for the 30-day stale cleanup.
  -- Use this for staleness, never created_at: an old token can still be in daily use.
  last_seen_at  timestamptz not null default now(),

  created_at    timestamptz not null default now()
);

-- Index on user_id. Postgres does NOT automatically index foreign-key columns.
-- We look tokens up by user constantly ("send this push to all of Alice's devices"),
-- and the cascade delete also has to find a user's rows. Without an index, both
-- scan the whole table.
create index push_tokens_user_id_idx on push_tokens (user_id);

-- ─── Lock the table to direct access (ADR-006) ──────────────────────
-- Same as profiles: authorization lives in the Express API (service-role key).
-- RLS on with no policies + revoke → the public anon key can't reach this table.
alter table push_tokens enable row level security;
revoke all on push_tokens from anon, authenticated;

-- migrate:down

drop table push_tokens;
