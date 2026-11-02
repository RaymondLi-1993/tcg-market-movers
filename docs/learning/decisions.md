# Decision Log

Short ADR-style (Architecture Decision Record) entries. Each one records what we decided, what else we considered, and why. Add new entries at the bottom and never rewrite old ones. If a decision changes, add a new entry that supersedes it.

---

## ADR-001: Use the Supabase web dashboard instead of the CLI (for now)
**Date:** 2026-10-29
**Status:** Accepted

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
