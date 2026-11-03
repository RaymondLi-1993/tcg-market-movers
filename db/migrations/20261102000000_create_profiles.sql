-- Create profiles: one row = one user's app settings (one-to-one with the Supabase Auth user).
-- Design notes: docs/product/data-model/01-profiles.md
-- Run with dbmate: `npm run db:up` (apply) / `npm run db:down` (undo, dev only).

-- migrate:up

create table profiles (
  -- The user's ID, the same ID Supabase Auth gives the user.
  --   primary key                → one profile per user (unique + never empty)
  --   references auth.users(id)  → must be a real Supabase Auth user
  --   on delete cascade          → deleting the user deletes this profile (Story 6, hard delete)
  user_id         uuid primary key references auth.users(id) on delete cascade,

  -- Timezone name (not an offset) so daylight saving is handled automatically.
  -- Story 5: decides when it's 10pm-8am for this user (silent pushes).
  -- Defaults to 'UTC' until the app saves the device's timezone on sign-in.
  timezone        text not null default 'UTC',

  -- Story 2: in-app switch to turn alerts off. New users start with alerts on.
  alerts_enabled  boolean not null default true,

  -- When the profile was created (engagement analytics, e.g. signups per week).
  created_at      timestamptz not null default now()
);

-- ─── Lock the table to direct access (ADR-006) ──────────────────────
-- All access goes through our Express API, which uses the service-role key
-- (bypasses RLS) and does the authorization in Node ("is this your profile?").
-- The mobile app still holds the public anon key (needed for Supabase Auth
-- sign-in), and that key could call Supabase's data API directly, skipping our
-- API. So we lock that door:
--   - RLS on with NO policies → every direct anon/authenticated request is refused
--   - revoke table privileges → a second lock, in case RLS is ever turned off by mistake
-- Profile creation happens in the API (first authenticated request), not a trigger.
alter table profiles enable row level security;
revoke all on profiles from anon, authenticated;

-- dbmate's own tracking table (schema_migrations) also lives in the public
-- schema, which Supabase exposes via its data API. Lock it the same way.
alter table schema_migrations enable row level security;
revoke all on schema_migrations from anon, authenticated;

-- migrate:down

drop table profiles;
