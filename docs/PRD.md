# Product Requirements Document (PRD)

**Project:** EA License System  
**Version:** 0.1.0  
**Last Updated:** 2024-12-20

---

## Product Definition

A SaaS platform that manages software licenses for MetaTrader Expert Advisors (EAs), enabling traders to register accounts, validate licenses, and download trading bots.

---

## Target User Persona

**Primary User: Retail Forex Trader**
- Uses MetaTrader 4 or MetaTrader 5
- Purchases automated trading systems (EAs)
- Needs to register trading accounts for license validation
- May have multiple broker accounts
- Technical ability: Can follow instructions but not a developer

**Secondary User: Administrator**
- Manages user approvals
- Controls EA access permissions
- Monitors validation logs

---

## Core Problem Solved

Traders who purchase EAs need a way to:
1. Prove they legitimately own the EA
2. Register specific trading accounts for use
3. Download the compiled EA files
4. Have the EA validate its license when running

Without this system, EAs would either be unprotected (piracy) or require manual license management.

---

## MVP Scope (Current State)

### ✅ What Currently Exists

| Feature | Status |
|---------|--------|
| User registration & login | Working |
| Dashboard with navigation | Working |
| MT4/MT5 account registration | Working |
| License validation API (`/api/validate`) | Working |
| EA file downloads (.ex4/.ex5) | Working (partial - 13 MT4, 8 MT5 files) |
| Admin user management | Working |
| Admin EA management | Working |
| Validation logging | Working |
| Rate limiting | Working (in-memory) |
| Subscription tiers (1/5/10 accounts) | Working |
| Trade performance tracking | Schema exists, UI exists |
| Notification settings | Schema exists, UI exists |
| Referral program | Schema exists, UI exists |

### ⏳ Partially Complete
- Trade sync from EAs (schema only)
- Telegram/Discord notifications (settings UI only)
- Referral rewards (tracking only)

---

## Explicit Non-Goals

These features are **intentionally NOT included** in this project:

1. **Payment processing** - No Stripe/PayPal integration
2. **Email notifications** - No transactional emails
3. **Email verification** - Users can register with any email
4. **Password reset flow** - Not implemented
5. **Multi-language support** - English only
6. **Mobile app** - Web only
7. **Real-time trade dashboard** - Not WebSocket-based
8. **EA marketplace** - No purchasing/selling EAs
9. **Two-factor authentication** - Single factor only
10. **OAuth providers** - Credentials only (no Google/GitHub login)

---

## Success Criteria

### Must Work (P0)
1. User can register and login
2. User can add trading accounts
3. EA can validate license via API
4. User can download EA files
5. Admin can approve users
6. Admin can grant EA access

### Should Work (P1)
1. Validation logs are recorded
2. Rate limiting prevents abuse
3. User sees their API key
4. Dashboard loads without errors

### Nice to Have (P2)
1. Trade performance displays correctly
2. Referral tracking works
3. Notification settings save

---

## Primary User Flows

### Flow 1: New User Registration → First EA Download
```
1. User visits /register
2. User enters name, email, password
3. System creates account (isApproved = false)
4. User is redirected to /dashboard
5. User sees "Awaiting Approval" message
6. Admin approves user in /admin/users
7. User can now access all features
8. User goes to /accounts → adds trading account
9. User goes to /downloads → clicks MT4 or MT5 button
10. Browser downloads .ex4/.ex5 file
```

### Flow 2: EA License Validation (from MetaTrader)
```
1. EA starts in MetaTrader
2. EA sends POST to /api/validate with:
   - Header: X-API-Key: [user's API key]
   - Body: { accountNumber, brokerName, eaCode, eaVersion, terminalType }
3. Server validates:
   - API key exists and user is active/approved
   - EA exists and user has access
   - Account is registered to this user
4. Server returns { valid: true } or { valid: false, errorCode: "..." }
5. EA proceeds or shows error based on response
```

### Flow 3: Admin Grants EA Access
```
1. Admin logs into /admin
2. Admin goes to /admin/users
3. Admin clicks on a user
4. Admin toggles EA access for specific EAs
5. System updates user_ea_access table
6. User can now validate/download that EA
```

---

## Secondary Flows

### Logout
```
1. User clicks avatar in navbar
2. User clicks "Logout"
3. NextAuth clears session cookie
4. User redirected to /login
```

### View API Key
```
1. User goes to /api-keys
2. System displays user's API key (masked by default)
3. User can click to reveal/copy
```

### Password Reset
```
❌ NOT IMPLEMENTED
Workaround: Admin manually resets in database
```

---

## Stability Assessment

### Stable (unlikely to change)
- Database schema for core entities (User, MtAccount, ExpertAdvisor, UserEaAccess)
- Validation API contract (`/api/validate` request/response format)
- Authentication flow (NextAuth + JWT)
- Dashboard layout and navigation

### Likely to Change
- Trade performance features (incomplete)
- Notification integrations (Telegram/Discord)
- Referral reward logic
- Rate limiting strategy (move to Redis)
- MQL file structure and compilation fixes

---

*End of PRD*
