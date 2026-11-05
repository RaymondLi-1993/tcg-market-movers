-- Create run_cards_log: one row = one card variant that a worker run saw (analytics + tuning).
-- Lets us ask "what did the 2pm run see?" and test thresholds against real data.
-- Admin-only: the app never reads this table.
--
-- The values are SNAPSHOTS, copied on purpose. card_prices is overwritten every run,
-- so this is the only record of what a price was at that moment.
-- Name, set, and image aren't copied because they rarely change: join to cards for those.
-- The date isn't copied either: it comes from the run (worker_runs.started_at).

-- migrate:up

create table run_cards_log (
  -- Which run saw this. Deleting a run deletes its log rows.
  run_id               bigint not null references worker_runs(id) on delete cascade,

  -- Which card and variant it saw. Same not null rule as card_prices: these are in the key.
  card_id              uuid not null references cards(id) on delete cascade,
  condition            text not null,
  printing             text not null,

  -- What the run saw. Same types as card_prices, and empty if the provider sent nothing.
  price                numeric(10, 2),
  pct_change_24h       numeric(8, 2),
  pct_change_7d        numeric(8, 2),
  trading_activity_7d  integer check (trading_activity_7d >= 0),

  -- One row per variant per run, so a retried run can't log the same variant twice.
  -- run_id comes first, so "everything this run saw" is already fast.
  primary key (run_id, card_id, condition, printing)
);

-- ─── Lock the table to direct access (ADR-006) ──────────────────────
alter table run_cards_log enable row level security;
revoke all on run_cards_log from anon, authenticated;

-- migrate:down

drop table run_cards_log;
