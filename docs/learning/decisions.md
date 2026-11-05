# Decision Log

Short ADR-style (Architecture Decision Record) entries. Each one records what we decided, what else we considered, and why. Add new entries at the bottom and never rewrite old ones. If a decision changes, add a new entry that supersedes it.

---

## ADR-001: Use the Supabase web dashboard instead of the CLI (for now)
**Date:** 2026-10-29
**Status:** Superseded by ADR-007 (schema changes now go through dbmate migrations)

**Context:** There's a single developer at the MVP stage. The Supabase CLI adds local dev (which needs Docker), migrations, and type generation, but it's another tool to learn alongside mobile and backend fundamentals.

**Decision:** Manage Supabase through the web dashboard. To keep the main benefits of the CLI:
- Use two hosted projects: `tcg-dev` as a sandbox and `tcg-prod` for real users.
- Write every schema change as a numbered SQL file in `supabase/sql/`, review it in a PR, then paste it into the SQL Editor (dev first, then prod).
- Write TypeScript DB types by hand in `packages/shared`.

**Alternatives considered:**
- *Supabase CLI + local Docker stack:* gives the best reproducibility and safety, but adds more setup and learning overhead right now.
- *Dashboard with no SQL files:* the fastest option, but leaves no history or review and can't be reproduced.

**Consequences:** Applying changes by hand risks drift between dev and prod if a file is skipped. Revisit before App Store launch: adopt the CLI and convert `supabase/sql/` into migrations.

---

## ADR-002: Launch on the App Store as a portfolio goal, using free tiers everywhere else
**Date:** 2026-10-29
**Status:** Accepted

**Context:** It's unclear whether many people will use the app, so costs should stay minimal. The project is also a portfolio piece, and shipping a real App Store app is a goal in its own right.

**Decision:**
- Keep the full plan through to an App Store launch (Phases 1–6). Pay the Apple Developer Program fee ($99/yr) near the end of Phase 4, when push notifications and TestFlight first need it.
- Stay on free tiers for everything else (Supabase, Expo/EAS, JustTCG, GitHub Actions). Upgrade only when real usage forces it.
- Keep the scope inside free-tier limits. For example, limit price ingestion to a subset of cards (recent sets, or cards above a minimum price) if JustTCG's free request limits require it.
- Make the GitHub repo public so recruiters can see it and GitHub Actions minutes are free.

**Alternatives considered:**
- *Test demand first with a free Discord/web movers feed, and pay Apple only if success metrics are met:* the cheapest way to test demand, but it doesn't meet the portfolio goal of a shipped App Store app. Kept as an optional growth channel after launch.
- *Android first (Google Play ~$25 one-time):* cheaper, but iOS is the main target. Android can follow, since Expo builds both.

**Consequences:** The one guaranteed cost is $99/yr. Free-tier limits (Supabase pausing, JustTCG requests, EAS build quota) constrain the design and must be checked as we go. Because the repo is public, secrets rules must be followed strictly.

---

## ADR-003: Store owners as primary user, collectors secondary; Market Movers as the MVP
**Date:** 2026-10-29
**Status:** In review (amended before acceptance to add collectors as a secondary user)

**Context:** The app sends push alerts on big Pokémon card price moves. We had to decide who it's for and what it watches, under the JustTCG free tier: 1,000 requests/month (~33/day sustained), 100/day, 20 cards per request. That budget can't cover the full catalog card by card. JustTCG's `GET /cards` can sort by price change, which allows market-wide coverage in a few requests. Store owners have a concrete, costly pain: if a card spikes and they don't notice, they sell under market value. If it drops, they overpay when buying cards from customers.

**Decision:**
- **Primary user: store owners.** Stories and alert content are designed for repricing and buying decisions.
- **Secondary user: collectors.** They use the same feed and pushes in the MVP, so if their card makes a big market-wide move, they'll see it. What they really want is "did *my* card move?", which is the per-user watchlist. Together with store owners' "my stock", that makes watchlists the **first post-MVP feature**.
- **MVP: Market Movers.** The worker queries the whole market about 4 times a day using sorted gainers and losers (about 4 requests per run, ~16/day). It filters out noise and shares the results with every user ("fetch once, serve many").
- **Strict, low-volume push:** a summary push lists only "big" moves (≥25% and ≥$20, NM prices, actively traded, 72h cooldown per card). It covers both directions, sends at most one push per run, and only between 8am and 10pm local time. It shows the top 3 moves plus "+N more", and tapping leads through to TCGplayer so the owner can act.
- **The feed is public.** Signing in unlocks alerts and preferences (App Review 5.1.1).
- **Per-user watchlists come later**, funded by leftover API budget (~17 requests/day) or JustTCG Starter ($19/mo) once demand justifies it.

**Alternatives considered:**
- *Collectors as the primary user:* a bigger audience, but their main need ("my card moved") requires watchlists, which the MVP budget doesn't support yet. The space is also crowded with collection trackers. They're kept as a secondary user instead.
- *A curated global watchlist (~200 hand-picked cards):* fits the budget, but needs ongoing manual curation and misses moves on cards not on the list.
- *Per-user watchlists from day one:* what store owners eventually want ("my stock"), but API cost grows with the number of unique cards watched. That breaks the flat-cost model on the free tier, and it adds UI for adding and managing cards.
- *One push per card, or looser thresholds:* faster to act on, but risks spam. Users who get spammed turn notifications off, which kills the core feature.

**Consequences:**
- API cost stays flat no matter how many users there are, and roughly half the daily budget is left for retries and future watchlists.
- The quality of alerts depends on noise filtering, because % sorting puts cheap cards with few sales at the top. A run may need an extra page, so there's a hard cap per run.
- Strict thresholds may mean days without a push. Check against a week of real data in Phase 3 and only make them stricter.
- Neither store owners nor collectors can target "my cards" yet. That's the most likely first feature request from both groups and the trigger for the watchlist work.
- Depends on JustTCG's sorted queries. If they change, the `PriceProvider` adapter isolates the impact.

---

## ADR-004: Supabase-first backend, with no separate Node/Express API (for now)
**Date:** 2026-11-02
**Status:** Superseded by ADR-005 (same day)

**Context:** The developer comes from a background where business rules live in a Node/Express API server. The original plan had no custom API server (the app talks directly to Supabase, and security lives in the database), but that wasn't explained clearly up front, so the question came up again before writing more SQL. Constraints: $0 hosting with no surprise bills (ADR-002), the fastest path to an App Store launch, and the developer wants real backend experience. An API answers user requests at any time, so it can't sleep. Free always-on hosting either sleeps (slow first loads), requires a card (bill risk, e.g. Google Cloud Run, AWS), or means a second platform (e.g. Vercel).

**Decision:**
- **The app talks directly to Supabase** using the anon key. **The guarantees live in the database:** keys, foreign keys, cascade deletes, RLS policies (which rows), column grants (which columns), and triggers (e.g. auto-create profile).
- **Trusted or secret logic runs in Supabase Edge Functions** (TypeScript on Deno): the scheduled worker (Supabase cron), plus small endpoints that need the service-role key (e.g. `delete-account`). Use **Hono** where Express-style routing helps.
- **Keep business logic portable:** write it as plain TypeScript modules (budget guard, mover selection, push building), separate from the thin Edge Function wrapper, so moving to Node/Express later is mostly a wrapper swap.

**Alternatives considered:**
- *Full Node/Express API (the app only talks to Node):* the most familiar and résumé-recognizable, but every action needs an endpoint and it needs always-on hosting (~$5–7/mo or a card on file). More than this app needs right now.
- *Hybrid (public reads straight from Supabase, writes via a Node API on Vercel/Cloud Run):* a good learning balance at $0 on Vercel, but it adds a second platform and deploy pipeline before the MVP needs one.
- *Supabase cron triggering a Node worker hosted elsewhere:* real Node for the worker, but two platforms and an extra endpoint to secure.

**Consequences:**
- $0, no card, one platform, and less to deploy and monitor.
- Security depends on getting RLS and grants right on every table. Every table gets RLS on, plus explicit policies, and RLS is tested on `tcg-dev` (e.g. confirm another user's rows can't be read).
- RLS mistakes are often silent (0 rows, no error), so tests and dashboard checks matter.
- Edge Functions run on Deno, not Node: mostly the same TypeScript, with a few runtime differences.
- **Revisit** if the app needs substantial custom API logic, if the developer wants a Node/Express portfolio piece, or if Edge Function limits become a problem. Moving to hybrid (Express on Vercel) is the likely next step.

---

## ADR-005: Full Node/Express API on Netlify Functions; the app never queries the database directly
**Date:** 2026-11-02
**Status:** Accepted. Supersedes ADR-004. Auth/RLS details amended by ADR-006.

**Context:** Right after ADR-004, the developer chose to build a Node layer, mainly **to learn Node/Express backend development** (portfolio and career value). We confirmed security was *not* the reason: secrets are equally protected in Edge Function secrets and Node environment variables. Two more concerns came up: (1) with direct database reads, bots can hammer the public data API (RLS limits *what* they see, not *how often* they ask); (2) the developer wants $0 hosting with no card, which rules out Google Cloud Run/AWS (card required) and paid always-on hosts.

**Decision:**
- **Full API:** the mobile app talks **only to our Express API**. It never queries Supabase tables directly. Sign-in still uses **Supabase Auth** from the app (Google/Apple), and the app sends its session token to the API.
- **Hosting: Netlify Functions (free tier, no card).** Express runs as serverless functions via an adapter (`serverless-http`). Netlify's current free limits get checked during setup.
- **Auth in Node:** middleware verifies the Supabase session token and gets the user ID. For user actions, the API uses a Supabase client **acting as that user**, so **RLS still applies as a second layer** (defense in depth). The service-role key is only used where it's genuinely needed (worker, account deletion).
- **Database rules stay:** keys, foreign keys, cascades, triggers, RLS, and column grants from the SQL files remain. Node is the main gate, and the database is the backup.
- **Caching:** public GET endpoints (e.g. `/movers`, `/cards/:id`) send `Cache-Control: public, s-maxage=…` (short, ~1–5 min) so Netlify's CDN serves repeats. That gives bot protection and speed, and stays within free limits. **User-specific endpoints are never cached** (`private, no-store`). No Redis until a measured need.
- **Rate limiting** on the API (shared store such as Upstash if needed on serverless) is planned before launch.
- **Worker:** where it runs (Supabase cron calling a secured Netlify function, or Netlify scheduled functions) is decided in Phase 2. Business logic stays in plain TypeScript modules either way.

**Alternatives considered:**
- *Supabase-first (ADR-004):* the least code and one platform, but less Node learning, and the public data API is open to request floods.
- *Hybrid (public reads direct from Supabase, private actions through Node):* less code and faster feed reads, but two doors to secure (RLS + Node) and still an open public data API.
- *Other hosts:* Vercel (similar, also free with no card), Cloudflare Workers (no card, but Express doesn't fit well, so Hono instead), Google Cloud Run/AWS Lambda (card required, risk of a bill), Render free (sleeps, slow cold starts).

**Consequences:**
- The most Node/Express learning: routes, auth middleware, validation, caching headers, error handling, rate limiting.
- One door: authorization logic lives in TypeScript (easier to test), with RLS as a backup.
- More code: an endpoint for every action, including the feed.
- Netlify becomes a single point of failure: if it's down, the app is down.
- Serverless cold starts may add latency to uncached requests. The CDN cache hides most of it for the feed.
- The app depends only on our API, so the database or host can change later without an app release.

---

## ADR-006: Authorization lives in the Node API; the database is locked to direct access
**Date:** 2026-11-02
**Status:** Accepted. Amends ADR-005 (auth in Node, RLS as backup).

**Context:** With a full Node API (ADR-005), the developer wants authorization rules ("who can see or change what") in the application layer, not the database. One catch: the mobile app still holds the public Supabase anon key (Supabase Auth sign-in needs it), and that key can call Supabase's data API directly, skipping our API.

**Decision:**
- **Authorization lives in Express.** The API verifies the user's session token, then checks permissions in code (e.g. a user can only read and update their own profile, and only `timezone`/`alerts_enabled`). The API talks to Postgres with the **service-role key**.
- **The database is locked to direct access:** every table has **RLS on with no policies**, plus `revoke all … from anon, authenticated`. Direct requests using the anon key get nothing.
- **Data-integrity rules stay in the database:** primary keys, foreign keys, `on delete cascade`, `not null`, defaults, unique constraints. These keep the data valid regardless of bugs in the code.
- **Profile auto-creation moves to the API:** on a user's first authenticated request, the API creates their profile if missing (an idempotent upsert). This replaces the database trigger.

**Alternatives considered:**
- *Keep per-user RLS policies + column grants as a second layer (ADR-005 as written):* stronger defense in depth, but rules would live in two places (SQL + Node) and could drift apart.
- *Delete RLS entirely:* ❌ anyone extracting the anon key from the app could read and modify every table.
- *Keep the auto-create trigger:* it runs at the exact moment of sign-up and can't be skipped, but the developer wants app-layer logic. The API upsert is idempotent, so a missed first request just creates the profile on the next one.

**Consequences:**
- One place for authorization logic (TypeScript, testable).
- The service-role key is now used for **every** request, so a bug in an authorization check exposes data. **Every route needs explicit auth checks + tests** (e.g. "user A can't read user B's profile").
- Leaking the service-role key would be critical. It lives only in Netlify environment variables.
- Every new table must get the same lock (RLS on, no policies, revoke from anon/authenticated) in its SQL file.

---

## ADR-007: Schema changes via dbmate migrations (raw SQL, up/down)
**Date:** 2026-11-02
**Status:** Accepted. Supersedes ADR-001's "paste SQL files into the dashboard" approach.

**Context:** ADR-001 avoided tooling by pasting numbered SQL files into the Supabase SQL Editor, and accepted the risk that dev and prod could drift apart. Just before applying the first table, the developer asked for proper up/down migrations. Nothing had been applied yet, so this was the cheapest moment to switch.

**Decision:**
- Use **dbmate** (npm dev dependency, pinned per project) with **raw SQL** migrations in `db/migrations/`, one file per change with `-- migrate:up` and `-- migrate:down` sections.
- Commands via npm scripts: `db:new`, `db:up`, `db:down`, `db:status`. Schema dumps are off (`--no-dump-schema`) because `pg_dump` isn't installed.
- dbmate connects with `DATABASE_URL` from a **git-ignored `.env`**, using the Supabase session-pooler connection string. `.env.example` documents the format.
- dbmate's tracking table `schema_migrations` lives in the public schema, so it's locked like every other table (RLS on, privileges revoked from anon/authenticated).
- **Down migrations are for dev.** Production is treated as **forward-only**: fix mistakes with a new migration, because rolling back can delete data.
- The Supabase dashboard is still used to **inspect** (Table Editor, logs), never to change the schema.

**Alternatives considered:**
- *Keep pasting into the dashboard (ADR-001):* no tooling, but no record of what ran where.
- *Supabase CLI migrations:* raw SQL, but forward-only (no down).
- *golang-migrate:* raw SQL with separate up/down files (more files). *node-pg-migrate:* JavaScript-first. *Flyway:* undo is a paid feature. *Prisma/Drizzle migrations:* only sensible together with that ORM in the API.

**Consequences:**
- Every environment gets the same changes in the same order, tracked in `schema_migrations`.
- The database password now sits in a local `.env`, which must never be committed.
- Later: CI can run `db:up` against `tcg-prod` on merge to `main`.

---

## ADR-008: JustTCG v2 scan, and a sales-backed push rule (from real API data)
**Date:** 2026-11-05
**Status:** Accepted. Replaces ADR-003's push threshold (≥25%, ≥$20, trading activity). The rest of ADR-003 stands.

**Context:** The first real JustTCG calls (2026-11-05, 6 requests) tested the plan's assumptions:
- **v1** sorts by 24h change, but has no price filter. Page 1 of 31,724 cards was mostly sub-$5 cards, and only 3 of 20 were ≥$20 and ≥25%.
- **v2 (beta)** has `min_price` and `order_by=24h`. With `min_price=20` (8,139 cards), page 1 reached +20%. `order=asc` returned the biggest drops even though the spec doesn't list it.
- **Most big moves are thin:** of 17 cards at ≥$20 and ≥25%, none had ≥2 sales of the moved variant in 30 days. The spec confirms a missing window means zero sales. Actively traded cards moved less (18–45%).
- Each response includes all conditions/printings (about 7 variants per card), so there's no extra cost per condition.
- JustTCG has no images, and pokemontcg.io is deprecated.
- Prices were ~4.5h old, and price history uses daily points, so real-time isn't achievable.

**Decision:**
- **Fetch:** v2 `GET /v2/cards` with `game=pokemon&language=English&min_price=20`, `order_by=24h` for gainers and `order_by=24h&order=asc` for drops, ~3 requests per run. Results are checked for correct ordering because `order=asc` is undocumented.
- **Push rule:** Near Mint variant ≥$20, ≥20% in 24h either way, and ≥5 sales of Near Mint + Lightly Played copies in 30 days across all printings. Matching moves in other conditions add a "confirmed" badge but aren't required. No rarity filter. 72h cooldown per card.
- **Schema:** a new migration adds `sales_30d` to `card_prices` and `run_cards_log`. Card-wide totals are derived, never stored.
- **Positioning:** "real moves within a few hours", not "real-time".
- **Images:** a separate source, probably TCGdex (to verify).

**Alternatives considered:**
- *Keep v1 only:* stable and documented, but cheap cards bury useful moves, and getting past them would blow the budget.
- *A tracked list of active cards:* reliable, but the API can't sort by sales, and it costs ~15 requests per 300 cards per check. Not needed while the scan surfaces enough. Revisit if it doesn't.
- *Sales of the moved variant only, or same printing only:* cleaner, but on 2026-11-05 data they left 0–1 alerts.
- *Whole-card sales across all conditions:* inflated by Damaged/Played copies (e.g. Mewtwo: 13 card-wide, but the NM copy sold once).
- *Raising the move threshold above 20%:* mainly removed the actively traded cards.
- *Requiring matching moves:* matched 0 of 14 candidates.

**Consequences:**
- Depends on a beta API and one undocumented parameter. The `PriceProvider` adapter isolates the shape, and the worker validates sorting.
- Still mixes printings (e.g. Blastoise: 11 NM+LP sales across printings, 3 in the printing that moved). Accepted for now.
- Rules are tuned on one day of data, so recheck with `run_cards_log` after a week.
- Expect few pushes per day, which fits quality over quantity.

