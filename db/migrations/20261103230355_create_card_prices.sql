-- Create card_prices: one row = one card × one condition × one printing
-- (e.g. "Charizard ex, Near Mint, Holofoil"). One card → many price rows.
-- OVERWRITTEN every worker run (current state, no history): the worker upserts
-- on (card_id, condition, printing). JustTCG keeps the history for us.

-- migrate:up

create table card_prices (
  id                   uuid primary key default gen_random_uuid(),

  -- The card this price belongs to. A price means nothing without its card.
  card_id              uuid not null references cards(id) on delete cascade,

  -- Which variant this row is, e.g. 'Near Mint' + 'Holofoil'. Both are in the
  -- unique key below, so both are not null (nulls never count as duplicates).
  condition            text not null,
  printing             text not null,

  -- Current price in USD. numeric is exact; float would store approximations.
  -- Empty when the provider has no current market report.
  price                numeric(10, 2),

  -- Percent change, e.g. 32.50 = +32.5% (not dollars). Used by the feed and push rules.
  -- Empty when the provider doesn't have enough history yet.
  pct_change_24h       numeric(8, 2),
  pct_change_7d        numeric(8, 2),

  -- How many times the price changed this week (noise filter + confidence badge).
  -- Empty = unknown, which is different from 0 = never changed.
  trading_activity_7d  integer check (trading_activity_7d >= 0),

  -- Price range. Badges like "All-time high" are derived by comparing these to
  -- price, never stored as flags.
  all_time_high        numeric(10, 2),
  all_time_low         numeric(10, 2),
  low_90d              numeric(10, 2),
  high_90d             numeric(10, 2),

  -- Chart data from the provider, a list of {p, t} points. Read whole, never
  -- queried inside, so jsonb is enough. Overwritten each run; it never grows.
  price_history        jsonb,

  -- TCGplayer's ID for this exact variant, used to build the "View on TCGplayer" link.
  -- text because it's an outside ID. Empty if the provider doesn't send one.
  tcgplayer_sku_id     text,

  -- When OUR worker last wrote this row (the feed's 24h window).
  -- The default only covers inserts, so the worker's upsert must also set it to now().
  updated_at           timestamptz not null default now(),

  -- When the PROVIDER last saw this price ("price as of…"). Can be empty.
  source_updated_at    timestamptz,

  -- One row per variant. Also the key the worker's upsert matches on. It starts
  -- with card_id, so it also serves "all prices for card X" without a separate index.
  unique (card_id, condition, printing)
);

-- ─── Lock the table to direct access (ADR-006) ──────────────────────
alter table card_prices enable row level security;
revoke all on card_prices from anon, authenticated;

-- migrate:down

drop table card_prices;
