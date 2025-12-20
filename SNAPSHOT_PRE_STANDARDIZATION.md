# Pre-Standardization Snapshot

**Created:** 2024-12-20
**Commit:** 0ee82a2
**Tag:** `pre-standardization`

## Project Overview

| Platform | Location |
|----------|----------|
| GitHub | https://github.com/nutbitzuist/ea-license-system |
| Vercel | ea-license-system.vercel.app |
| Railway | Project ID: 30198fc4-b023-4e7f-a973-e7871ff987a2 |

## How to Restore

```bash
# Restore to this snapshot
git checkout pre-standardization

# Or create a branch from this snapshot
git checkout -b restore-branch pre-standardization
```

---

## Core Flows That Must Not Break

### 1. User Authentication
- [ ] Login with email/password works
- [ ] Session persists across page refresh
- [ ] Logout clears session

### 2. License Validation (API)
- [ ] `POST /api/validate` accepts EA validation requests
- [ ] Returns `{"valid": true}` for registered accounts
- [ ] Returns error for invalid/expired licenses

### 3. EA Downloads
- [ ] Downloads page shows available EAs
- [ ] MT4 download button downloads `.ex4` file
- [ ] MT5 download button downloads `.ex5` file
- [ ] Returns "file not available" for missing files

### 4. Dashboard
- [ ] Dashboard loads without errors
- [ ] Shows user's licensed EAs
- [ ] Navigation works between pages

---

## Verification Checklist

Before making changes, verify these URLs work:

1. **Login:** https://myalgostack.com/login
2. **Dashboard:** https://myalgostack.com/dashboard
3. **Downloads:** https://myalgostack.com/downloads
4. **API Health:** https://myalgostack.com/api/validate (POST)

---

## Files Changed Since Last Major Version

Recent commits:
- `0ee82a2` - Update download API to serve compiled EX4/EX5 files
- `cede69d` - fix: Use placeholder DATABASE_URL for Prisma generate
- `2264771` - feat: Add Trade Performance, Notifications, and Referral features
