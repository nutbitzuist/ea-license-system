# Architecture Decisions & Rationale (DECISIONS)

**Project:** EA License System  
**Last Updated:** 2024-12-20

---

## Architecture Decisions Made

### 1. Next.js App Router (not Pages Router)
**Decision:** Use Next.js 14 with App Router  
**Rationale:**
- Modern React patterns with Server Components
- Built-in layouts and loading states
- API routes colocated with app
- Better TypeScript support

**Trade-off:** Newer, less community examples than Pages Router

---

### 2. Credentials-Only Authentication
**Decision:** Use NextAuth with Credentials provider only (no OAuth)  
**Rationale:**
- Simpler implementation
- No external auth provider dependencies
- Users expect email/password for trading software
- API key auth for EAs requires our own user database anyway

**Trade-off:** No social login convenience, must handle password security ourselves

---

### 3. JWT Sessions (not Database Sessions)
**Decision:** Stateless JWT tokens stored in cookies  
**Rationale:**
- No database lookup on every request
- Scales horizontally without session store
- 30-day expiry reduces login friction

**Trade-off:** Cannot immediately revoke sessions (must wait for expiry)

---

### 4. PostgreSQL via Supabase
**Decision:** Use Supabase-hosted PostgreSQL with Prisma ORM  
**Rationale:**
- Relational data model fits license management
- Prisma provides type-safe queries
- Supabase offers managed hosting with good free tier
- Connection pooling handled by Supabase

**Trade-off:** Vendor lock-in to Supabase, Prisma abstraction layer

---

### 5. API Key Authentication for EAs
**Decision:** EAs use API key in header, not JWT  
**Rationale:**
- EAs can't do OAuth flows
- API key is simpler to embed in EA code
- User can regenerate if compromised
- One key per user (not per EA or account)

**Trade-off:** API key in EA code could be extracted; relies on obfuscation

---

### 6. Compiled EA Files in Git Repository
**Decision:** Store .ex4/.ex5 files directly in `/mql/` folder  
**Rationale:**
- Simple deployment (files ship with app)
- No external file storage needed
- Version controlled with code

**Trade-off:** Large binary files in git, repo size grows

---

### 7. Manual User Approval
**Decision:** New users require admin approval (`isApproved` flag)  
**Rationale:**
- Prevents automated abuse
- Admin can verify payment externally
- Simple gatekeeper for MVP

**Trade-off:** Friction for new users, admin overhead

---

### 8. Single Rate Limiter for Validation
**Decision:** Rate limit by API key, in-memory store  
**Rationale:**
- Fast implementation
- Prevents EA spam
- 60 requests per 60 seconds is reasonable for EA startup

**Trade-off:** Resets on cold starts, won't work across multiple instances

---

### 9. No Email System
**Decision:** No transactional emails (no verification, no password reset)  
**Rationale:**
- Reduces complexity for MVP
- Avoids email deliverability issues
- Admin can manually assist users

**Trade-off:** No self-service password recovery, no signup verification

---

### 10. Monorepo with MQL Files
**Decision:** Keep MQL source files and compiled files in same repo  
**Rationale:**
- Single source of truth
- Version history for EA changes
- Easy to see what's deployed

**Trade-off:** Developers need MetaTrader to compile, repo larger

---

## Things Intentionally Avoided

| Feature | Why Avoided |
|---------|-------------|
| GraphQL | REST is simpler for this use case |
| Microservices | Overkill for current scale |
| WebSockets | No real-time requirements yet |
| Redis | In-memory sufficient for MVP |
| Docker | Vercel/Railway handle deployment |
| Custom auth | NextAuth handles the heavy lifting |
| Payment processing | Out of scope (handled externally) |
| Mobile app | Web-first approach |

---

## Guidance for Future Changes

### When Adding New EAs
1. Add EA record to `expert_advisors` table via admin UI
2. Place compiled files in `/mql/MQL4/Experts/` and `/mql/MQL5/Experts/`
3. **Update** the `eaCodeToFileMap` in `/api/eas/[eaCode]/download/route.ts`
4. Test download from dashboard

### When Changing Auth
1. Review `src/lib/auth.ts` for NextAuth config
2. Review `src/middleware.ts` for route protection
3. Test both web login AND API key validation
4. Never change the JWT token structure without updating all session checks

### When Changing Validation API
1. Update `validateLicenseSchema` in `/lib/validations.ts`
2. Update all deployed EAs if request format changes
3. Maintain backward compatibility if possible
4. Document changes in versioned API if breaking

---

## ⚠️ Do Not Change Casually

### Critical Files
| File | Risk | Why |
|------|------|-----|
| `src/lib/auth.ts` | HIGH | Breaks all authentication |
| `src/middleware.ts` | HIGH | Could expose protected routes |
| `src/app/api/validate/route.ts` | HIGH | Breaks all deployed EAs |
| `prisma/schema.prisma` | MEDIUM | Requires migration |
| `src/lib/db.ts` | MEDIUM | Single DB connection point |

### Critical Contracts
- **API key header:** Always `X-API-Key`
- **Validation endpoint:** Always `POST /api/validate`
- **Response format:** Always `{ valid: boolean, message: string, ... }`
- **Error codes:** Keep existing codes, only add new ones

### Protected Patterns
- User must be `isApproved` before validating
- User must be `isActive` to access anything
- Admin routes require `role === "ADMIN"`
- EA access checked via `user_ea_access` table

---

*End of DECISIONS*
