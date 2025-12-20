# Test Plan (TEST_PLAN)

**Project:** EA License System  
**Last Updated:** 2024-12-20

---

## Auth Smoke Test

### Test: User Login Flow
**Precondition:** User account exists and is approved

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/login` | Login form displayed |
| 2 | Enter valid email and password | Fields accept input |
| 3 | Click "Sign In" | Page redirects to `/dashboard` |
| 4 | Check navbar | User name displayed |
| 5 | Refresh page | Still logged in (session persists) |
| 6 | Click avatar → Logout | Redirected to `/login` |
| 7 | Try to access `/dashboard` | Redirected to `/login` |

### Test: Invalid Login
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enter wrong password | Error message shown |
| 2 | Enter non-existent email | Error message shown |
| 3 | Submit empty form | Validation errors shown |

---

## Core Flow Smoke Tests

### Test: Account Registration
**Precondition:** User is logged in and approved

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/accounts` | Account list displayed |
| 2 | Click "Add Account" | Form/dialog opens |
| 3 | Enter account details | Fields accept input |
| 4 | Submit form | Account appears in list |
| 5 | Delete account | Account removed from list |

### Test: EA Download
**Precondition:** User has EA access, compiled file exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/downloads` | EA list displayed |
| 2 | Click "MT4" button on available EA | File download starts |
| 3 | Check downloaded file | Valid .ex4 file |
| 4 | Click "MT5" button | File download starts |
| 5 | Check downloaded file | Valid .ex5 file |

### Test: License Validation API
**Precondition:** User approved, account registered, EA access granted

```bash
# Test with curl
curl -X POST https://myalgostack.com/api/validate \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "accountNumber": "12345678",
    "brokerName": "Test Broker",
    "eaCode": "ma_crossover_ea",
    "eaVersion": "1.0.0",
    "terminalType": "MT4"
  }'
```

| Scenario | Expected Response |
|----------|-------------------|
| Valid request | `{ "valid": true, "message": "License valid" }` |
| Invalid API key | `{ "valid": false, "errorCode": "INVALID_CREDENTIALS" }` |
| Unregistered account | `{ "valid": false, "errorCode": "ACCOUNT_NOT_FOUND" }` |
| No EA access | `{ "valid": false, "errorCode": "EA_ACCESS_DENIED" }` |
| User not approved | `{ "valid": false, "errorCode": "USER_NOT_APPROVED" }` |

### Test: Admin User Management
**Precondition:** Logged in as admin

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/admin/users` | User list displayed |
| 2 | Click on unapproved user | User details shown |
| 3 | Toggle "Approved" switch | User becomes approved |
| 4 | Toggle EA access | Access updated |

---

## Edge Cases to Verify Manually

### Authentication Edge Cases
- [ ] Expired JWT token → Should redirect to login
- [ ] Tampered JWT token → Should reject and redirect
- [ ] Deleted user tries to access → Should fail gracefully
- [ ] Deactivated user logs in → Should show error

### Validation Edge Cases
- [ ] Rate limit exceeded (60+ requests/minute) → Returns 429
- [ ] Malformed JSON body → Returns 400
- [ ] Missing required fields → Returns 400 with details
- [ ] Expired EA access → Returns 403 with EXPIRED code
- [ ] Inactive EA → Returns 403

### Download Edge Cases
- [ ] Missing .ex4 file → Returns 404 with message
- [ ] User without EA access → Returns 403
- [ ] Expired EA access → Returns 403
- [ ] Non-existent EA code → Returns 404

---

## Error Checks

### Check Browser Console For:
- [ ] No JavaScript errors on page load
- [ ] No React hydration errors
- [ ] No 500 errors in Network tab
- [ ] No CORS errors

### Check Server Logs For:
- [ ] No unhandled promise rejections
- [ ] No Prisma connection errors
- [ ] No authentication errors for valid users
- [ ] Rate limit working correctly

### Check Database For:
- [ ] Validation logs being recorded
- [ ] `lastValidatedAt` updating on accounts
- [ ] No orphaned records

---

## Pre-Deploy Checklist

### Before Every Deploy
- [ ] `npm run build` completes without errors
- [ ] All environment variables set in Vercel/Railway
- [ ] Database migrations applied (if any)
- [ ] Test login on staging/preview

### Before Major Releases
- [ ] Run all smoke tests above
- [ ] Test validation API with real EA
- [ ] Verify all EA files are present
- [ ] Check admin functions work
- [ ] Verify rate limiting works

---

## Must Pass Before Shipping

### P0 - Absolute Requirements
1. [ ] User can login with correct credentials
2. [ ] User cannot access dashboard without login
3. [ ] Admin routes protected from regular users
4. [ ] Validation API returns correct response for valid license
5. [ ] Validation API rejects invalid API key
6. [ ] EA files download correctly
7. [ ] No sensitive data in error responses

### P1 - Should Verify
1. [ ] Rate limiting prevents abuse
2. [ ] Validation logs are recorded
3. [ ] Account registration works
4. [ ] API key regeneration works
5. [ ] Logout clears session

---

## Regression Test Triggers

Run full test suite when changing:
- `src/lib/auth.ts`
- `src/middleware.ts`
- `src/app/api/validate/route.ts`
- `prisma/schema.prisma`
- Any file in `src/lib/`

Run smoke tests when changing:
- Any API route
- Dashboard pages
- Component files

---

*End of TEST_PLAN*
