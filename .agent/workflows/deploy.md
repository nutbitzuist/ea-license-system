---
description: Deploy changes to GitHub, Vercel, and Railway
---

# Deployment Workflow

This workflow pushes changes to all platforms after making code changes.

## Project Configuration

| Platform | ID/Link |
|----------|---------|
| **GitHub** | https://github.com/nutbitzuist/ea-license-system |
| **Vercel Project ID** | `prj_wvR6HJH0GD6iIOw5WeI7dbkgVfRl` |
| **Railway Project ID** | `30198fc4-b023-4e7f-a973-e7871ff987a2` |

## Steps

### 1. Commit and Push to GitHub
```bash
git add -A
git commit -m "Your commit message"
git push origin main
```

### 2. Deploy to Vercel
// turbo
```bash
vercel --prod --yes
```
Note: Vercel auto-deploys from GitHub. Manual deploy only if needed.

### 3. Deploy to Railway
// turbo
```bash
railway up --detach
```
Note: Project is already linked. Use `railway status` to check.

## Quick Deploy Command (All-in-One)
```bash
git add -A && git commit -m "update" && git push origin main && vercel --prod --yes && railway up
```
