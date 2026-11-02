-- 001_profiles.sql
-- One row = one user's app settings (one-to-one with the Supabase Auth user).
-- Design notes: docs/product/data-model/01-profiles.md

create table profiles (
  -- The user's ID, the same ID Supabase Auth gives the user.
  user_id         uuid,

  -- Timezone name (not an offset) so daylight saving is handled automatically.
  -- Story 5: decides when it's 10pm-8am for this user (silent pushes).
  -- Defaults to 'UTC' until the app saves the device's timezone on sign-in.
  timezone        text not null default 'UTC',

  -- Story 2: in-app switch to turn alerts off. New users start with alerts on.
  alerts_enabled  boolean not null default true,

  -- When the profile was created (engagement analytics, e.g. signups per week).
  created_at      timestamptz not null default now()
);
