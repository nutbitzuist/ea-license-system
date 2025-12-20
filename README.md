# EA License System

A SaaS platform for managing MetaTrader Expert Advisor (EA) licenses, enabling traders to register accounts, validate licenses, and download trading bots.

## What This App Does

- **User Management:** Registration, login, account approval workflow
- **Account Registration:** Users register their MT4/MT5 trading accounts
- **License Validation:** EAs call `/api/validate` to verify license
- **EA Downloads:** Users download compiled .ex4/.ex5 files
- **Admin Panel:** Manage users, EAs, and access permissions

## Tech Stack

- **Frontend:** Next.js 14 (App Router), React 18, Tailwind CSS
- **Backend:** Next.js API Routes
- **Database:** PostgreSQL (Supabase) via Prisma
- **Auth:** NextAuth.js (Credentials + JWT)
- **Hosting:** Vercel (frontend), Railway (backend)

## Setup (Local Development)

### Prerequisites
- Node.js 18+
- PostgreSQL database (or Supabase account)

### Installation

```bash
# Clone repository
git clone https://github.com/nutbitzuist/ea-license-system.git
cd ea-license-system

# Install dependencies
npm install

# Copy environment file
cp .env.example .env.local

# Edit .env.local with your values (see Environment Variables below)

# Generate Prisma client
npm run db:generate

# Push schema to database
npm run db:push

# Seed database (optional)
npm run db:seed

# Start development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

## Environment Variables

Create `.env.local` with these variables:

```
# Database
DATABASE_URL=

# NextAuth
NEXTAUTH_URL=
NEXTAUTH_SECRET=
AUTH_SECRET=

# Supabase (optional)
NEXT_PUBLIC_SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=

# App
NEXT_PUBLIC_APP_NAME=
NEXT_PUBLIC_APP_URL=
```

## How to Run

```bash
# Development
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Database commands
npm run db:generate   # Generate Prisma client
npm run db:push       # Push schema changes
npm run db:studio     # Open Prisma Studio
npm run db:seed       # Seed data
```

## How to Deploy

### Push to GitHub
```bash
git add -A
git commit -m "Your message"
git push origin main
```

### Deploy to Vercel
```bash
vercel --prod --yes
```

### Deploy to Railway
```bash
railway up --detach
```

### All-in-One
```bash
git add -A && git commit -m "update" && git push origin main && vercel --prod --yes && railway up --detach
```

## Project Structure

```
├── src/
│   ├── app/           # Next.js App Router pages
│   ├── components/    # React components
│   ├── lib/           # Utilities (auth, db, etc.)
│   └── middleware.ts  # Route protection
├── prisma/
│   ├── schema.prisma  # Database schema
│   └── seed.ts        # Seed data
├── mql/
│   ├── MQL4/Experts/  # MT4 EA files
│   └── MQL5/Experts/  # MT5 EA files
└── docs/              # Documentation
```

## Important Notes

1. **New users require admin approval** before they can validate licenses
2. **API Key** is used by EAs for validation (not JWT)
3. **Compiled EA files** must be placed in `/mql/MQL4/Experts/` and `/mql/MQL5/Experts/`
4. **Rate limiting** is in-memory and resets on cold starts
5. **No email system** - password reset requires admin intervention

## Documentation

- [PRD.md](./docs/PRD.md) - Product requirements
- [SPEC.md](./docs/SPEC.md) - Technical specification
- [TASKS.md](./docs/TASKS.md) - Status and tasks
- [DECISIONS.md](./docs/DECISIONS.md) - Architecture decisions
- [TEST_PLAN.md](./docs/TEST_PLAN.md) - Testing guide
- [ENGINEERING_STANDARD.md](./docs/ENGINEERING_STANDARD.md) - Coding standards

## License

Private - All rights reserved
