-- Create sent_push_cards: the JOIN TABLE between sent_pushes and cards (many-to-many).
-- One row = "this card was in this push". One push has many cards, and one card
-- appears in many pushes. It only connects the two tables, so it holds just the two FKs.

-- migrate:up

create table sent_push_cards (
  -- Which push. Deleting the push (e.g. the user deleted their account) removes its links.
  sent_push_id  uuid not null references sent_pushes(id) on delete cascade,

  -- Which card was in that push.
  card_id       uuid not null references cards(id) on delete cascade,

  -- The pair identifies the row, so this table needs no id column. It also stops the
  -- same card being linked to the same push twice.
  -- sent_push_id comes first, so "what cards were in this push?" is already fast.
  primary key (sent_push_id, card_id)
);

-- No separate index on card_id, on purpose: the app never searches by it and nothing
-- deletes cards. Add one later if analytics like "how often was this card pushed?" get slow.

-- ─── Lock the table to direct access (ADR-006) ──────────────────────
alter table sent_push_cards enable row level security;
revoke all on sent_push_cards from anon, authenticated;

-- migrate:down

drop table sent_push_cards;
