# User Stories (MVP)

**Primary user:** Pokémon card store owners.
**Secondary user:** collectors. They use the same Market Movers feed and pushes in the MVP. Their main need ("did _my_ card move?") is served by user watchlists, the first post-MVP feature.
**Format:** _As a … I want … so that …_, with **Acceptance** criteria that we can test.

---

## 1. Get notified of big market moves (core story)

_As a store owner, I want to be notified of big moves on cards in the market so that I can update my in-store prices or make purchases before the market catches up._

**Acceptance:**

- A push is sent only for "big" moves: **≥25% change and ≥$20 price**, on cards that trade actively.
- Both upward and downward moves count.
- **All conditions** (NM, LP, MP, HP, DMG) are tracked. A push is **per card, regardless of condition**: if any condition qualifies, the card is included, shown with its **biggest qualifying move** (e.g. "Charizard ex SIR ▲32% (NM)"). The user sees every condition in card detail.
- The same **card** (any condition) doesn't trigger another push within a cooldown window (72h).

## 2. Sign in to unlock alerts and preferences

_As a store owner, I want to sign in to the app so that I can receive alerts and save my preferences._

**Acceptance:**

- I can sign up and sign in with **Google** or **Apple** (Apple is required by App Store guideline 4.8 when Google is offered). Both go through Supabase Auth.
- I stay signed in between app launches, and I can sign out.
- Push alerts and preferences require being signed in. Browsing Market Movers does not (App Review 5.1.1).

## 3. Browse Market Movers without logging in

_As a store owner, I want a section showing the biggest recent price moves so that I can quickly see which cards I may need to reprice or buy._

**Acceptance:**

- The feed lists recent notable moves across the market (looser threshold than push, e.g. ≥10%), with noise filtered out (min price and trading activity).
- **One entry per card**, showing its biggest notable move: card name, image, condition, old → new price, % change, and direction.
- Entries show **badges** when they apply: **"All-time high"**, **"90-day low"**, and a **confidence signal** ("Actively traded" vs "Thin market", based on how often the price changed this week).
- The feed shows when prices were last updated.
- It works without an account.

## 4. Act on a summary push

_As a store owner, I want each push to list the biggest moves at a glance so that I can decide quickly whether to act, without being spammed._

**Acceptance:**

- At most one push per worker run (~4/day max).
- It shows the **top 3 moves + "+N more"**: name, % change, and old → new price.
- Notable moves get a short tag in the push text, e.g. "🔥 All-time high".
- Tapping it opens a "this run's moves" list. Each card opens a detail screen with a **"View on TCGplayer"** button.

## 5. Silent pushes at night

_As a store owner, I want to get big moves right away without being woken up at night so that I stay informed without being disturbed._

**Acceptance:**

- Between **10pm and 8am in the user's local time**, pushes are delivered **silently**: no sound, no screen wake, just placed in the notification list (fixed for MVP, not configurable).
- From 8am to 10pm, pushes are delivered normally.
- The user's timezone is saved from the device when they sign in.
- No separate daily cap: the strict threshold + max one push per run keeps volume low.
- To verify in Phase 5: Expo push supports iOS's quiet ("passive") delivery.

## 6. Delete my account

_As a user, I want to delete my account and all my data from inside the app so that I control my information._ (Required by Apple.)

**Acceptance:**

- Settings has a "Delete account" action with a confirmation step.
- Deleting removes the user's auth account, profile, push tokens, and alert history.
- After deletion, the device receives no more pushes and the app returns to the signed-out state.

## 7. See why a card moved

_As a store owner, I want a card detail screen so that I can judge whether a move is real before I reprice or buy._

**Acceptance:**

- Shows current price, old → new price, % change (24h and 7d), and a recent price-history chart.
- Shows trading activity (e.g. "price changed 14 times this week") and the **confidence signal**, so thin or one-off moves are obvious.
- Shows **where the price sits in its range**: all-time high/low and the 90-day range, with the same badges as the feed.
- Shows **every condition** (NM, LP, MP, HP, DMG, and printings such as Holofoil vs Reverse Holofoil) with its own price and change.
- Has a "View on TCGplayer" button per condition.
- Works without an account.

## 8. Refresh movers within the API budget (system)

_As the system, I want to fetch market movers on a schedule without exceeding the JustTCG free-tier limits so that the app keeps working and costs stay at $0._

**Acceptance:**

- Each run uses a capped number of requests (~4, hard maximum per run), at ~4 runs/day.
- The worker stops before hitting the daily/monthly limit, and backs off and retries on `429`.
- A failed or partial run never corrupts existing data. The feed keeps showing the last good results.
- Each run records when it ran and how many requests it used.

## Future (not MVP)

**No extra API cost (uses data we already fetch):**

- Personal minimum price ("only alert me on cards ≥$50"), filtered on our side
- Suggested buy price for store owners (e.g. 60–70% of market)
- Weekly recap push ("This week's 5 biggest moves")
- Share a mover (image/link) for Discord and social media

**Costs extra API budget or effort:**

- **User watchlists, first post-MVP feature.** _As a collector, I want alerts when cards I own make a big move so that I know what my collection is worth._ / _As a store owner, I want alerts on cards I stock._ Funded by leftover API budget, or JustTCG Starter.
- Sealed product (booster boxes, ETBs): check JustTCG coverage first
- Graded cards (PSA 10 etc.) via JustTCG's graded endpoint
- Japanese cards (JustTCG `language`)
- "Why it moved" context (reprints, tournament results, set releases): needs a news source or manual curation
- TCGplayer affiliate links (income without subscriptions; needs an ADR)
