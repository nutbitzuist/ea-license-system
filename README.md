# My Algo Stack

**Your Trading Infrastructure** — A comprehensive platform for automated trading with MetaTrader Expert Advisors.

## Features

- **40+ Premium EAs**: Professional-grade trading algorithms for MT4/MT5
- **Money Management**: Auto-lot sizing based on risk percentage
- **Trailing Stop & Break Even**: Dynamic profit protection
- **License Management**: Control which accounts can run your EAs
- **14-Day Free Trial**: Test all features before subscribing
- **Dashboard**: Manage MT accounts, view analytics, access API credentials
- **Cloud-Ready**: Runs on your infrastructure or ours (coming soon)

## Tech Stack

- **Framework**: Next.js 14+ with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS + shadcn/ui
- **Authentication**: NextAuth.js
- **Database**: PostgreSQL (Supabase)
- **ORM**: Prisma

## Getting Started

### Prerequisites

- Node.js 18+
- PostgreSQL database (Supabase recommended)

### Installation

1. Clone and install:
```bash
cd myalgostack
npm install
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your database URL and secrets
```

3. Set up database:
```bash
npx prisma generate
npx prisma db push
```

4. Run development server:
```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to access the platform.

## MQL Integration

Copy MQL files to your MetaTrader installation:

**MT5:** `mql/MQL5/Experts/` → `MQL5/Experts/`
**MT4:** `mql/MQL4/Experts/` → `MQL4/Experts/`

**Important:** Add the API URL to allowed WebRequest URLs in MetaTrader:
`Tools -> Options -> Expert Advisors -> Allow WebRequest`

## API

### License Validation
```
POST /api/validate
Headers: X-API-Key: <your_license_key>
Body: { accountNumber, brokerName, eaCode, eaVersion, terminalType }
```

## Deployment

```bash
npm run build
# Deploy via Vercel CLI or GitHub integration
```

## License

MIT
