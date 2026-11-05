-- Create cards: one row = one card (the facts that RARELY change: name, set, image…).
-- Prices live in a separate table, card_prices (next migration): one card → many prices.
-- The worker upserts cards from JustTCG each run, matching on (provider, provider_card_id).

-- migrate:up

create table cards (
  -- Our own primary key (surrogate key): other tables point at OUR id, never JustTCG's,
  -- so switching or adding providers doesn't break foreign keys.
  id                uuid primary key default gen_random_uuid(),

  -- Which price source this card came from, e.g. 'justtcg'. Set by the provider adapter.
  -- No default on purpose: a forgotten value should fail loudly, not be silently mislabeled.
  provider          text not null,

  -- The provider's own ID for this card. text because we don't control its format.
  provider_card_id  text not null,

  name              text not null,      
  set_name          text,                
  set_number        text,                

  -- Link to the card image (we store the link, not the image). Empty if the provider has none yet.
  image_url         text,

  -- When this card was last included in a push (72h cooldown, per card, any condition).
  -- Empty = never pushed. No default: now() would put every new card straight into cooldown.
  last_pushed_at    timestamptz,

  -- When WE first saw this card (debugging/analytics). Not the card's release date.
  created_at        timestamptz not null default now(),

  -- One row per provider card. Also the key the worker's upsert matches on.
  -- Both columns are not null: in a unique constraint, nulls never count as duplicates.
  unique (provider, provider_card_id)
);

-- ─── Lock the table to direct access (ADR-006) ──────────────────────
alter table cards enable row level security;
revoke all on cards from anon, authenticated;

-- migrate:down

drop table cards;
