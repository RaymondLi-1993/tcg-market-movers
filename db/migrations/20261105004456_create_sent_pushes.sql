-- Create sent_pushes: one row = one push sent to one user, from one worker run (an event).
-- If a user has two devices, the same push goes to both, but it's still ONE row.
-- Devices come from push_tokens, and the cards in the push come from sent_push_cards.

-- migrate:up

create table sent_pushes (
  -- Its own primary key, so sent_push_cards can point at it.
  id       uuid primary key default gen_random_uuid(),

  -- Who received this push. Deleting the user deletes their push history (Story 6, hard delete).
  user_id  uuid not null references auth.users(id) on delete cascade,

  -- Which worker run created this push. bigint to match worker_runs.id.
  -- No "on delete" rule: runs are a permanent log, so Postgres refuses to delete one in use.
  run_id   bigint not null references worker_runs(id),

  sent_at  timestamptz not null default now(),

  -- One push per user per run, so a retried or restarted run can't send a duplicate.
  -- These columns stay the same across retries, unlike id. Its index starts with
  -- user_id, so it also serves "all pushes for this user".
  unique (user_id, run_id)
);

-- ─── Lock the table to direct access (ADR-006) ──────────────────────
alter table sent_pushes enable row level security;
revoke all on sent_pushes from anon, authenticated;

-- migrate:down

drop table sent_pushes;
