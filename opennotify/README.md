# OpenNotify

A modern SaaS that monitors whether a public Instagram profile's visibility changes
(public ↔ private) and notifies you the moment a change is detected.

> **Safety by design:** OpenNotify does **not** scrape Instagram. Profile status is
> resolved through a pluggable `ProfileChecker` interface. The default provider is a
> safe deterministic simulation (`mock`), so the entire product — change detection,
> notifications, history — works end-to-end without touching any external service.
> To go to production, implement the interface against a licensed data provider or
> an official API and register it in `CheckerModule`; nothing else changes.

## Stack

| Layer      | Tech |
|------------|------|
| Web        | Next.js 15, TypeScript, Tailwind CSS 4, Framer Motion, TanStack Query |
| Mobile     | Flutter, Material 3, Riverpod, GoRouter |
| Backend    | NestJS, PostgreSQL, Prisma, Redis, BullMQ, JWT |
| Infra      | Docker Compose (frontend, backend, postgres, redis) |

## Quick start (Docker)

```bash
docker compose up --build
```

- Web app: http://localhost:3000
- API: http://localhost:4000/api/v1
- Swagger docs: http://localhost:4000/api/docs

Seed demo data (after the stack is up):

```bash
docker compose exec backend sh -c "npx ts-node prisma/seed.ts" \
  || (cd backend && DATABASE_URL=postgresql://opennotify:opennotify@localhost:5432/opennotify npm run seed)
```

Demo accounts (password `Password123!`):
- `demo@opennotify.app` — regular user with seeded profiles and history
- `admin@opennotify.app` — admin (admin panel enabled)

## Local development

```bash
# infra only
docker compose up -d postgres redis

# backend
cd backend
cp .env.example .env
npm install
npx prisma migrate dev
npm run seed
npm run start:dev        # http://localhost:4000

# frontend
cd frontend
npm install
npm run dev              # http://localhost:3000

# mobile (Android emulator reaches the API via 10.0.2.2)
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:4000/api/v1
```

## Architecture

```
backend/src
├── common/            # decorators, guards
├── infra/prisma/      # PrismaService (repository pattern sits on top)
└── features/
    ├── auth/          # email/password, Google ID-token login, refresh rotation,
    │                  # email verification, forgot/reset password
    ├── users/         # profile, settings, delete account, push devices
    ├── profiles/      # monitored profiles CRUD + history + dashboard stats
    ├── monitoring/    # BullMQ queue, cron scheduler, ProfileChecker abstraction
    │   └── checker/   # ProfileChecker interface + mock provider registry
    ├── notifications/ # in-app / email / push channels behind one service
    ├── billing/       # plans, limits, Stripe-ready checkout stubs
    └── admin/         # users, profiles, stats, audit logs
```

Key decisions:

- **Modular checker** — `PROFILE_CHECKER` is an injection token resolved from
  `PROFILE_CHECKER_PROVIDER`. Adding a real provider means one class + one registry
  entry.
- **Repository pattern** — Prisma access is isolated in `*.repository.ts` files so
  services stay testable and storage-agnostic.
- **Queue-based monitoring** — a cron scheduler enqueues stale profiles into BullMQ;
  workers check, diff, persist `StatusChange` rows and fan out notifications. Scales
  horizontally by adding workers.
- **Secure JWT handling** — short-lived access tokens + hashed, rotating refresh
  tokens stored server-side (revocable). Helmet, rate limiting (global + stricter on
  auth endpoints), class-validator on every input, structured pino logging with
  header redaction.
- **Plan limits** — enforced server-side (`Free` 5 / `Pro` 100 / `Business`
  unlimited). `BillingService.createCheckoutSession` is the single point to wire
  Stripe into later.

## API

REST, versioned under `/api/v1`, fully documented with Swagger at `/api/docs`.
Validation via `class-validator`, auth via `Authorization: Bearer <accessToken>`.

## Environment variables

See `backend/.env.example`. Frontend uses `NEXT_PUBLIC_API_URL`; mobile uses
`--dart-define=API_URL=...`.

## Checker providers

Selected via `PROFILE_CHECKER_PROVIDER`:

- **`mock`** (default) — deterministic simulation; no external calls. Safe for
  development and demos.
- **`instagram_web`** — resolves real visibility from Instagram's public
  `web_profile_info` endpoint (the same JSON the website itself fetches). No login
  and no API key. Instagram rate-limits by IP, so under bursts it returns HTTP 429
  and the checker resolves to `UNKNOWN`; errors never crash a check. Fine for low
  volume with the default 15-minute interval, but not for high throughput from a
  single IP.

## Risks of monitoring Instagram data

- Automated collection violates Instagram's Terms of Use; the official Graph API
  only covers accounts you manage.
- Aggressive anti-bot measures: login walls, IP rate limits, challenges, account
  bans for logged-in scraping.
- Markup/endpoints change frequently, making scrapers brittle.
- Legal/compliance exposure (ToS enforcement, GDPR/KVKK obligations when processing
  third-party data).

Recommended production path for scale: a licensed third-party data provider (or
rotating proxies) implemented behind `ProfileChecker` — one class + one registry
entry, nothing else changes.
