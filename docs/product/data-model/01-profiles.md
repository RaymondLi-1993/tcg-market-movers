# profiles

> Part 1 of the data model. Holds **our app's facts about a user**. Login details (ID, email, Google/Apple identity) live in Supabase Auth, not here.

## What one row represents

**One user's app settings.** Every signed-in user has exactly one profile.

## Columns

| Column           | Example               | Why (which story)                                                                                                |
| ---------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `user_id`        | `7f3a9c2e-…`          | Links the profile to its Supabase Auth user. Also the primary key (see Relationships). Stories 2, 6.             |
| `timezone`       | `America/Los_Angeles` | Story 5: decides when it's 10pm–8am _for this user_, so pushes are delivered silently at night.                  |
| `alerts_enabled` | `true`                | Story 2: the in-app switch to turn alerts off without deleting the account. The worker skips users with `false`. |
| `created_at`     | `2026-10-30 09:14`    | Engagement analytics (e.g. signups per week).                                                                    |

**Why a timezone name, not an offset:** an offset like `UTC-8` is only correct half the year. A name like `America/Los_Angeles` applies daylight saving automatically (−8 in winter, −7 in summer).

## Relationships

- **One Auth user ↔ one profile (one-to-one).**
- Because there's exactly one profile per user, the profile **reuses the user's ID as its primary key** instead of having its own ID. That keeps it simple and makes a second profile for the same user impossible.

```
Supabase Auth user (id, email)  ──  profiles (user_id, timezone, alerts_enabled)
```

## Rules

- **Uniqueness:** `user_id` is the primary key, so each user can have only one profile.
- **On delete: hard delete.** When a user deletes their account, the Auth user is deleted and the profile goes with it automatically (cascade). Apple requires real deletion of the account and its data. Marking it "inactive" doesn't count.
- **When it's created:** automatically, the moment a user first signs in (the Auth user is created → a profile is created with defaults: `alerts_enabled = true`, `timezone` from the device). The app never has to remember to create it.
- **When `timezone` updates:** the app re-saves the device timezone on each app open, so travel or moving is picked up.
- **Who can read/write:** only the user themselves (their own row), plus the worker (which reads it to decide who gets pushes). Enforced by RLS in the SQL step.

## What we chose NOT to store (and why)

- **Name and photo:** Google/Apple offer them, but no story displays them. **Data minimization:** only store personal data you actually use. Less to declare on the App Store privacy label, and less at risk if data ever leaks.
- **Email:** already stored by Supabase Auth, so we don't duplicate it.
- **An "inactive" / soft-delete flag:** `alerts_enabled = false` covers "take a break", and account deletion must be a real delete.

## Future

- **Personal minimum price** ("only alert me on cards ≥ $50"): one value per user, so it would be **a new column here**.
- **Watchlists** ("my cards"): many cards per user, so it's **a separate table** (users ↔ cards, many-to-many), not a column here.
