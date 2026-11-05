-- Add sales_30d: how many sales a variant had in the last 30 days (from the provider).
-- Needed by the push rule (decided 2026-11-05): a card must have >= 5 sales in 30 days
-- across ALL its variants ("card-wide sales"). That total is DERIVED by summing
-- sales_30d over a card's rows, never stored, so it can't go out of sync.
--
-- not null default 0: the provider omits a window that had no sales ("a missing window
-- means zero sales"), so missing really means 0, not unknown.
-- New migration instead of editing the old ones: applied migrations are history.

-- migrate:up

alter table card_prices
  add column sales_30d integer not null default 0 check (sales_30d >= 0);

-- Same snapshot in the tuning log, so thresholds can be checked against real data.
alter table run_cards_log
  add column sales_30d integer not null default 0 check (sales_30d >= 0);

-- migrate:down

alter table run_cards_log drop column sales_30d;
alter table card_prices drop column sales_30d;
