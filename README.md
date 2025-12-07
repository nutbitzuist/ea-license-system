# EA License Management System

A web-based license management system for MetaTrader Expert Advisors (EAs). Control which MT4/MT5 trading accounts can run specific EAs through a centralized dashboard and validation API.

## Features

- **User Dashboard**: Manage MT accounts, view available EAs, and access API credentials
- **Admin Panel**: Approve users, manage EAs, grant/revoke access, view validation logs
- **License Validation API**: Real-time license validation for EAs
- **MQL Library**: Ready-to-use MQL4/MQL5 include files for EA integration
- **Subscription Tiers**: Support for different account limits (1, 5, or 10 accounts)
- **Grace Period**: EAs continue working temporarily if server is unreachable

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

1. Clone the repository and install dependencies:
```bash
cd ea-license-system
npm install
```

2. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your database URL and secrets
```

3. Set up the database:
```bash
npx prisma generate
npx prisma db push
```

4. Create an admin user (optional - run in Prisma Studio or directly in DB):
```sql
-- After registering, update the first user to be admin and approved
UPDATE users SET role = 'ADMIN', "isApproved" = true WHERE email = 'your@email.com';
```

5. Run the development server:
```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to access the application.

## Environment Variables

```env
# Database
DATABASE_URL="postgresql://..."

# NextAuth
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="your-secret-key"
AUTH_SECRET="your-secret-key"

# Supabase (optional, for file storage)
NEXT_PUBLIC_SUPABASE_URL="https://xxx.supabase.co"
SUPABASE_SERVICE_ROLE_KEY="your-key"
```

## MQL Integration

Copy the MQL library files to your MetaTrader installation:

**For MT5:**
- Copy `mql/MQL5/Include/EALicense/` to `MQL5/Include/`
- Copy `mql/MQL5/Experts/Example_EA_With_License.mq5` to `MQL5/Experts/`

**For MT4:**
- Copy `mql/MQL4/Include/EALicense/` to `MQL4/Include/`
- Copy `mql/MQL4/Experts/Example_EA_With_License.mq4` to `MQL4/Experts/`

**Important:** Add your API endpoint URL to the allowed URLs in MetaTrader:
Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL

## API Endpoints

### License Validation (for EAs)
```
POST /api/validate
Headers:
  X-API-Key: <user_api_key>
  X-API-Secret: <user_api_secret>
Body: {
  accountNumber: "12345678",
  brokerName: "ICMarkets",
  eaCode: "scalper_pro_v1",
  eaVersion: "1.0.0",
  terminalType: "MT5"
}
```

### User APIs
- `GET /api/accounts` - List user's MT accounts
- `POST /api/accounts` - Add new MT account
- `GET /api/eas` - List available EAs
- `GET /api/credentials` - Get API credentials

### Admin APIs
- `GET /api/admin/users` - List all users
- `PATCH /api/admin/users/:id` - Update user settings
- `POST /api/admin/users/:id/grant-ea` - Grant EA access
- `GET /api/admin/eas` - List all EAs
- `POST /api/admin/eas` - Create new EA
- `GET /api/admin/logs` - View validation logs

## Deployment

Deploy to Vercel:

```bash
npm run build
# Deploy via Vercel CLI or GitHub integration
```

After deployment, update the `LICENSE_API_ENDPOINT` in the MQL Config.mqh files with your production URL.

## License

MIT
