# Engineering Standards

**Project:** EA License System  
**Last Updated:** 2024-12-20

---

## Core Philosophy

### 1. Boring > Clever
- Use standard patterns over creative solutions
- Prefer readable code over compact code
- If it needs a comment to explain, simplify it

### 2. Explicit > Implicit
- Name things clearly (no abbreviations)
- Document side effects
- Make dependencies visible

### 3. Delete > Add
- Remove unused code immediately
- Don't add features "just in case"
- Simpler is more maintainable

### 4. Working > Perfect
- Ship working code first
- Iterate based on real usage
- Perfect is the enemy of done

---

## How AI Is Allowed to Work on This Project

### ✅ AI CAN
- Make changes that match documented patterns
- Fix bugs that have clear reproduction steps
- Add features described in TASKS.md
- Refactor within existing file boundaries
- Update documentation to match code

### ⚠️ AI MUST ASK BEFORE
- Changing authentication flow
- Modifying validation API contract
- Adding new dependencies
- Changing database schema
- Creating new API routes
- Modifying middleware

### ❌ AI MUST NOT
- Remove auth checks without explicit approval
- Change API response formats
- Delete database migrations
- Modify production environment variables
- Skip testing changed auth code

---

## Build Rules

### Vertical Slices
Each feature should be self-contained:
```
/feature-name/
  - page.tsx       # UI
  - route.ts       # API (if needed)
  - types.ts       # Types (if needed)
```

### One Responsibility Per Layer
| Layer | Responsibility | NOT Allowed |
|-------|----------------|-------------|
| Page | Render UI, handle interactions | Database queries |
| API Route | Request/response handling, validation | Complex business logic |
| Lib | Shared utilities, DB access | UI components |
| Middleware | Auth checks, redirects | Data fetching |

### File Size Limits
- Pages: < 300 lines (extract components)
- API routes: < 200 lines (extract helpers)
- Components: < 150 lines (split if larger)

---

## Definition of "Feature Done"

A feature is complete when:

- [ ] **Works:** Happy path tested manually
- [ ] **Handles errors:** Error states handled gracefully
- [ ] **Protected:** Auth checks in place (if needed)
- [ ] **Typed:** No `any` types (TypeScript)
- [ ] **Documented:** Complex logic has comments
- [ ] **Builds:** `npm run build` passes
- [ ] **Deployed:** Live on production

### Definition of "Bug Fixed"
- [ ] Root cause identified
- [ ] Fix tested locally
- [ ] No regressions introduced
- [ ] Deployed and verified

---

## Change Discipline Rules

### Before Making Changes
1. Understand what the current code does
2. Check if change affects auth or validation
3. Review DECISIONS.md for relevant context
4. Create snapshot if major change

### While Making Changes
1. Make smallest change that works
2. Test locally after each significant change
3. Check for TypeScript errors
4. Review diff before committing

### After Making Changes
1. Update TASKS.md status
2. Update documentation if behavior changed
3. Test in staging before production
4. Monitor for errors after deploy

---

## Auth Protection Rules

### Every Protected Route Must
1. Check session exists (middleware)
2. Verify user is active
3. Check role if admin-only
4. Log access for audit (validation API)

### API Routes Pattern
```typescript
// At the start of every protected API route
const session = await getServerSession(authOptions)
if (!session?.user?.id) {
  return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
}
```

### Admin Routes Pattern
```typescript
// Additional check for admin routes
if (session.user.role !== "ADMIN") {
  return NextResponse.json({ error: "Forbidden" }, { status: 403 })
}
```

### Never Do This
```typescript
// ❌ WRONG: Trusting client-provided user ID
const userId = request.body.userId

// ✅ CORRECT: Always use session user ID
const userId = session.user.id
```

---

## Code Style

### Naming Conventions
- **Files:** kebab-case (`user-profile.tsx`)
- **Components:** PascalCase (`UserProfile`)
- **Functions:** camelCase (`getUserById`)
- **Constants:** SCREAMING_SNAKE (`MAX_ACCOUNTS`)
- **Types/Interfaces:** PascalCase (`UserSession`)

### Import Order
```typescript
// 1. External packages
import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"

// 2. Internal absolute imports
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"

// 3. Relative imports
import { UserCard } from "./user-card"
```

### Error Handling Pattern
```typescript
try {
  // Operation
  const result = await doSomething()
  return NextResponse.json(result)
} catch (error) {
  console.error("Operation failed:", error)
  return NextResponse.json(
    { error: "Something went wrong" },
    { status: 500 }
  )
}
```

---

## Commit Messages

### Format
```
type: short description

[optional body]
```

### Types
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `refactor:` Code change (no new feature)
- `chore:` Maintenance tasks

### Examples
```
feat: Add API key regeneration
fix: Prevent duplicate account registration
docs: Update deployment instructions
refactor: Extract validation logic to helper
chore: Update dependencies
```

---

## Testing Expectations

### Must Test Manually
- Any change to auth flow
- Any change to validation API
- New API routes
- Database schema changes

### Should Test Manually
- UI components with user interaction
- Error handling paths
- Edge cases documented in TEST_PLAN.md

### Can Skip Manual Testing
- Documentation changes
- Comment updates
- Type-only changes
- Style-only changes

---

## Performance Guidelines

### Database Queries
- Always use `select` to limit fields
- Avoid N+1 queries (use `include`)
- Add indexes for frequently queried fields

### API Responses
- Keep payloads small
- Don't return sensitive fields
- Use pagination for lists

### Frontend
- Lazy load heavy components
- Use React Query for caching
- Avoid unnecessary re-renders

---

*End of ENGINEERING_STANDARD*
