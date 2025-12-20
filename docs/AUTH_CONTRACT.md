# AUTH CONTRACT

**Project:** EA License System  
**Last Updated:** 2024-12-20  
**Status:** ⚠️ SACRED DOCUMENT - Changes require extra caution

---

## 1. AUTH MECHANISM

### Login Method
- **Type:** Email + Password
- **No OAuth:** No Google, GitHub, or social login
- **No Magic Link:** No passwordless email flow
- **No 2FA:** Single factor only

### Auth Provider
```
NextAuth.js v4.24.13
├── Provider: CredentialsProvider (only)
├── Adapter: None (using JWT, not database sessions)
└── Secret: NEXTAUTH_SECRET env var
```

### Password Handling
- **Library:** bcryptjs
- **Hash Rounds:** 12
- **Storage:** `users.passwordHash` column
- **Validation:** bcrypt.compare() at login

### Session Storage
| Attribute | Value |
|-----------|-------|
| Type | JWT (stateless) |
| Storage | HTTP-only cookie |
| Cookie Name | `next-auth.session-token` |
| Secure | Yes (production) |
| SameSite | Lax |
| Domain | Auto (same-site) |

---

## 2. PROTECTED ROUTES

### Public Routes (No Auth Required)

| Route | Purpose |
|-------|---------|
| `/` | Landing page |
| `/login` | Login form |
| `/register` | Registration form |
| `/api/auth/*` | NextAuth endpoints |
| `/api/validate` | EA license validation (uses API key, not session) |

### Protected Routes (Session Required)

| Route Pattern | Role Required | Purpose |
|---------------|---------------|---------|
| `/dashboard` | USER or ADMIN | Main dashboard |
| `/accounts` | USER or ADMIN | MT account management |
| `/downloads` | USER or ADMIN | EA file downloads |
| `/eas` | USER or ADMIN | Licensed EAs list |
| `/api-keys` | USER or ADMIN | View/regenerate API key |
| `/settings` | USER or ADMIN | User settings |
| `/performance` | USER or ADMIN | Trade performance |
| `/notifications` | USER or ADMIN | Notification settings |
| `/referrals` | USER or ADMIN | Referral program |
| `/analytics` | USER or ADMIN | Usage analytics |
| `/guide` | USER or ADMIN | User guide |

### Admin-Only Routes

| Route Pattern | Role Required | Purpose |
|---------------|---------------|---------|
| `/admin/*` | ADMIN only | Admin dashboard |
| `/api/admin/*` | ADMIN only | Admin API endpoints |

### Route Protection Enforcement

```typescript
// File: src/middleware.ts

// Check order:
1. Is it a public route? → Allow
2. Is it /api/validate? → Allow (API key auth)
3. Is it /api/admin/*? → Check JWT + role=ADMIN
4. Is it /admin/*? → Check JWT + role=ADMIN
5. Is it protected? → Check JWT exists
6. No JWT? → Redirect to /login
```

---

## 3. SESSION LIFECYCLE

### Session Creation
```
1. User submits email/password to /login
2. NextAuth calls authorize() in CredentialsProvider
3. Prisma queries user by email
4. bcrypt.compare() validates password
5. If valid: return user object { id, email, name, role, isApproved, isActive }
6. NextAuth jwt() callback adds fields to token
7. JWT token signed with NEXTAUTH_SECRET
8. Token set in HTTP-only cookie
```

### Session Validation (Every Request)
```
1. Middleware extracts token from cookie
2. getToken() verifies JWT signature
3. Token payload decoded (no DB lookup)
4. User properties available in session
```

### Session Refresh
- **Method:** Automatic via NextAuth
- **Behavior:** JWT extended on each request within expiry
- **No Manual Refresh:** No refresh token mechanism

### Session Expiry
- **Duration:** 30 days from last activity
- **Configured In:** `src/lib/auth.ts` → `session.maxAge`
- **After Expiry:** User must login again

### Session Destruction (Logout)
```
1. User clicks logout
2. signOut() called (NextAuth)
3. Cookie deleted
4. Redirect to /login
```

---

## 4. CRITICAL FILES

### 🔴 NEVER Modify Casually

| File | Risk Level | What It Controls |
|------|------------|------------------|
| `src/lib/auth.ts` | **CRITICAL** | All auth logic, JWT structure, session handling |
| `src/middleware.ts` | **CRITICAL** | Route protection, access control |
| `src/app/api/auth/[...nextauth]/route.ts` | **HIGH** | NextAuth handler |
| `src/app/api/auth/register/route.ts` | **HIGH** | User creation, password hashing |

### 🟡 Modify With Caution

| File | Risk Level | What It Controls |
|------|------------|------------------|
| `src/app/(auth)/login/page.tsx` | MEDIUM | Login form UI |
| `src/app/(auth)/register/page.tsx` | MEDIUM | Registration form UI |
| `src/app/api/validate/route.ts` | MEDIUM | API key validation |
| `prisma/schema.prisma` (User model) | MEDIUM | User fields, role enum |

### 🟢 Safe to Modify

| File | What It Controls |
|------|------------------|
| `src/app/(dashboard)/*` | Dashboard pages (protected by middleware) |
| `src/components/navbar.tsx` | Logout button, user display |

---

## 5. ENV VARS FOR AUTH

### Required Variables

```bash
# NextAuth Core
NEXTAUTH_URL="https://myalgostack.com"      # Production URL
NEXTAUTH_SECRET="<32+ char random string>"   # JWT signing secret

# Backup (some Next.js versions need this)
AUTH_SECRET="<same as NEXTAUTH_SECRET>"
```

### How to Generate Secret
```bash
openssl rand -base64 32
```

### Callback URLs

| URL | Purpose |
|-----|---------|
| `/api/auth/callback/credentials` | Post-login redirect (internal) |
| `/api/auth/signin` | Login page alias |
| `/api/auth/signout` | Logout handler |
| `/api/auth/session` | Session check endpoint |

### No External API Keys Required
- No OAuth client IDs
- No OAuth client secrets
- No third-party auth services

---

## 6. AUTH SMOKE TEST

### Prerequisites
- Application running locally or on staging
- Database accessible
- Test user credentials (or create new)

### Test Sequence

| Step | Action | Expected Result | Actual |
|------|--------|-----------------|--------|
| 1 | Navigate to `/register` | Registration form appears | ☐ |
| 2 | Enter name, email, password (8+ chars) | Form accepts input | ☐ |
| 3 | Click "Register" | Success toast, redirect to `/login` | ☐ |
| 4 | Enter registered email + password | Form accepts input | ☐ |
| 5 | Click "Sign In" | Redirect to `/dashboard` | ☐ |
| 6 | Check navbar | User name displayed | ☐ |
| 7 | Navigate to `/accounts` | Page loads (protected route works) | ☐ |
| 8 | Refresh page (F5) | Still on `/accounts`, still logged in | ☐ |
| 9 | Open new tab, go to `/dashboard` | Page loads (session persists across tabs) | ☐ |
| 10 | Click avatar → Logout | Redirect to `/login` | ☐ |
| 11 | Try to access `/dashboard` | Redirect to `/login` | ☐ |
| 12 | Check browser cookies | `next-auth.session-token` deleted | ☐ |

### Admin Test (If Admin User Exists)

| Step | Action | Expected Result | Actual |
|------|--------|-----------------|--------|
| 1 | Login as admin | Redirect to `/dashboard` | ☐ |
| 2 | Navigate to `/admin` | Admin dashboard loads | ☐ |
| 3 | Navigate to `/admin/users` | User list displayed | ☐ |
| 4 | Logout, login as regular user | - | ☐ |
| 5 | Try to access `/admin` | Redirect to `/dashboard` | ☐ |

### Password Reset Test
```
❌ NOT IMPLEMENTED

Workaround: Admin updates passwordHash directly in database
```

### Email Verification Test
```
❌ NOT IMPLEMENTED

Note: Users are auto-approved with 14-day trial
```

---

## 7. KNOWN AUTH FRAGILITIES

### What Has Broken Auth Before
| Issue | Cause | Resolution |
|-------|-------|------------|
| Session not persisting | Missing NEXTAUTH_SECRET | Set env var |
| Infinite redirect loop | Middleware config wrong | Fix matcher pattern |
| 500 on login | Prisma client not generated | Run `npx prisma generate` |
| Cookie not set | NEXTAUTH_URL mismatch | Match URL to domain |

### Risky Areas

| Area | Risk | Why |
|------|------|-----|
| JWT token structure | HIGH | Changing fields breaks existing sessions |
| Cookie settings | HIGH | Wrong settings = auth fails silently |
| Middleware matcher | HIGH | Wrong pattern = routes unprotected |
| Password hash rounds | MEDIUM | Changing breaks existing passwords |
| Session maxAge | LOW | Changing only affects new sessions |

### Must Test After Any Change

If you modify ANY auth file, run these tests:

1. [ ] Fresh registration works
2. [ ] Login with existing user works
3. [ ] Protected route redirects unauthenticated user
4. [ ] Session persists across page refresh
5. [ ] Logout clears session completely
6. [ ] Admin routes reject regular users
7. [ ] API routes reject unauthenticated requests
8. [ ] `/api/validate` accepts API key (not session)

---

## 8. API KEY AUTH (For EAs)

### Separate From Web Auth
- **Purpose:** EAs in MetaTrader can't do cookie auth
- **Method:** API key in HTTP header
- **Header Name:** `X-API-Key`
- **Stored In:** `users.apiKey` column

### API Key Flow
```
1. EA sends POST /api/validate with X-API-Key header
2. Server looks up user by apiKey
3. Validates user.isApproved and user.isActive
4. Returns { valid: true/false }
```

### API Key Properties
- Auto-generated on user creation (CUID)
- Never expires
- Can be regenerated by user
- One key per user (not per EA)

---

## Auth Code Quick Reference

### Check Session (API Route)
```typescript
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"

const session = await getServerSession(authOptions)
if (!session?.user?.id) {
  return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
}
```

### Check Admin Role
```typescript
if (session.user.role !== "ADMIN") {
  return NextResponse.json({ error: "Forbidden" }, { status: 403 })
}
```

### Check Session (Client Component)
```typescript
import { useSession } from "next-auth/react"

const { data: session, status } = useSession()
if (status === "loading") return <Loading />
if (!session) redirect("/login")
```

---

*This document is the source of truth for authentication. Any changes to auth must be reviewed against this contract.*

**Change Log:**
- 2024-12-20: Initial creation based on codebase analysis
