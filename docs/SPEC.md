# Technical Specification (SPEC)

**Project:** EA License System  
**Version:** 0.1.0  
**Last Updated:** 2024-12-20

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CLIENTS                                      │
├─────────────────────────────────┬───────────────────────────────────────┤
│     Web Browser (Dashboard)     │      MetaTrader EA (MT4/MT5)          │
│     - React SPA                 │      - Sends validation requests       │
│     - JWT in cookie             │      - Uses API Key in header          │
└────────────────┬────────────────┴──────────────────┬────────────────────┘
                 │                                    │
                 ▼                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           NEXT.JS APPLICATION                            │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │   Middleware    │  │   API Routes    │  │      React Pages        │  │
│  │  (auth check)   │  │  /api/*         │  │  /dashboard, /admin     │  │
│  └────────┬────────┘  └────────┬────────┘  └────────────┬────────────┘  │
│           │                    │                        │               │
│           ▼                    ▼                        ▼               │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      PRISMA ORM                                  │    │
│  │                    (Database Access)                             │    │
│  └──────────────────────────────┬──────────────────────────────────┘    │
└─────────────────────────────────┼───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         POSTGRESQL (Supabase)                            │
│  users | mt_accounts | expert_advisors | user_ea_access | validation_logs│
└─────────────────────────────────────────────────────────────────────────┘
```

---

## System Layers & Responsibilities

| Layer | Location | Responsibility |
|-------|----------|----------------|
| **Presentation** | `src/app/(dashboard)/*` | React pages, UI components |
| **Middleware** | `src/middleware.ts` | Route protection, auth checks |
| **API** | `src/app/api/*` | HTTP handlers, request validation |
| **Business Logic** | Inline in API routes | Validation rules, access control |
| **Data Access** | `src/lib/db.ts` + Prisma | Database queries |
| **Database** | PostgreSQL | Data persistence |

---

## Data Entities & Ownership

### Entity Ownership Rules

```
User (root entity)
├── OWNS → MtAccount[] (cascade delete)
├── OWNS → UserEaAccess[] (cascade delete)
├── OWNS → ValidationLog[] (cascade delete)
├── OWNS → Trade[] (cascade delete)
├── OWNS → NotificationSettings (cascade delete)
└── OWNS → Referral[] (as referrer, cascade delete)

ExpertAdvisor (admin-managed)
├── REFERENCED BY → UserEaAccess (set null on delete)
├── REFERENCED BY → ValidationLog (set null on delete)
└── REFERENCED BY → Trade (set null on delete)
```

### Key Constraints
- `User.email` - unique
- `User.apiKey` - unique
- `User.referralCode` - unique
- `MtAccount(userId, accountNumber, brokerName)` - unique composite
- `UserEaAccess(userId, eaId)` - unique composite
- `Trade(userId, mtAccountId, ticket)` - unique composite

---

## Auth Strategy & Session Model

### Authentication Method
- **Provider:** NextAuth.js (Credentials only)
- **Password Storage:** bcrypt hash in `users.passwordHash`
- **Session Type:** JWT (stateless)
- **Session Storage:** HTTP-only cookie
- **Session Duration:** 30 days

### JWT Token Contents
```typescript
{
  id: string,        // User ID
  email: string,     // User email
  name: string,      // User name
  role: "USER" | "ADMIN",
  isApproved: boolean,
  isActive: boolean,
  iat: number,       // Issued at
  exp: number        // Expiration
}
```

### API Key Authentication (for EAs)
- Stored in `users.apiKey` (auto-generated CUID)
- Passed via `X-API-Key` header
- Used only for `/api/validate` endpoint
- Never expires (until user regenerates)

---

## Access Control Rules

### Middleware Rules (`src/middleware.ts`)

| Route Pattern | Auth Required | Role Required |
|---------------|---------------|---------------|
| `/` | No | - |
| `/login`, `/register` | No | - |
| `/api/auth/*` | No | - |
| `/api/validate` | API Key (header) | - |
| `/dashboard/*` | Yes (JWT) | USER or ADMIN |
| `/admin/*` | Yes (JWT) | ADMIN only |
| `/api/admin/*` | Yes (JWT) | ADMIN only |
| `/api/*` (other) | Yes (JWT) | USER or ADMIN |

### Business Logic Rules
1. User must be `isApproved = true` to validate licenses
2. User must be `isActive = true` to access anything
3. User can only access EAs they have `UserEaAccess` for
4. User can only validate accounts they own
5. EA access can have expiration date (`expiresAt`)

---

## Auth Contract (NEVER CHANGE)

> ⚠️ **WARNING:** Changes to these interfaces will break all deployed EAs.

### Validation Request Contract
```typescript
// POST /api/validate
// Header: X-API-Key: <user's API key>
{
  accountNumber: string,  // e.g., "12345678"
  brokerName: string,     // e.g., "IC Markets"
  eaCode: string,         // e.g., "ma_crossover_ea"
  eaVersion: string,      // e.g., "1.0.0"
  terminalType: "MT4" | "MT5"
}
```

### Validation Response Contract
```typescript
// Success (200)
{
  valid: true,
  message: "License valid",
  gracePeriodHours: 24,
  serverTime: "2024-12-20T12:00:00Z"
}

// Failure (4xx)
{
  valid: false,
  message: "Human readable error",
  errorCode: "ACCOUNT_NOT_FOUND" | "EA_ACCESS_DENIED" | "USER_NOT_APPROVED" | ...
}
```

---

## API Routes Summary

| Method | Route | Auth | Purpose |
|--------|-------|------|---------|
| POST | `/api/validate` | API Key | EA license validation |
| GET | `/api/accounts` | JWT | List user's accounts |
| POST | `/api/accounts` | JWT | Add account |
| DELETE | `/api/accounts/[id]` | JWT | Delete account |
| GET | `/api/eas` | JWT | List user's EAs |
| GET | `/api/eas/[eaCode]/download` | JWT | Download EA file |
| GET | `/api/credentials` | JWT | Get API key |
| POST | `/api/credentials/regenerate` | JWT | Regenerate API key |
| GET | `/api/admin/users` | JWT+Admin | List all users |
| PATCH | `/api/admin/users/[id]` | JWT+Admin | Update user |
| GET | `/api/admin/eas` | JWT+Admin | List all EAs |
| POST | `/api/admin/eas` | JWT+Admin | Create EA |

---

## Failure Assumptions

### What Can Fail
1. **Database connection** - Supabase down or connection limit
2. **Cold start latency** - Serverless functions spin up
3. **Rate limiter reset** - In-memory store clears on deploy
4. **File not found** - EA .ex4/.ex5 file missing
5. **Invalid JSON** - Malformed request body

### How Failures Are Handled
| Failure | Current Handling |
|---------|------------------|
| DB connection | Returns 500, logs to console |
| Invalid auth | Returns 401/403 with error code |
| Missing file | Returns 404 with message |
| Rate limit | Returns 429 with retry-after |
| Invalid input | Returns 400 with validation errors |

---

## One-Source-of-Truth Rules

| Data | Source of Truth |
|------|-----------------|
| User data | `users` table |
| EA catalog | `expert_advisors` table |
| EA access | `user_ea_access` table |
| Session validity | JWT token (validated at runtime) |
| EA files | `/mql/MQL4/Experts/` and `/mql/MQL5/Experts/` |
| EA code → filename | Hardcoded in `/api/eas/[eaCode]/download/route.ts` |

---

*End of SPEC*
