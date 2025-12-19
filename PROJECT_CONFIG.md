# EA License System - Project Configuration

## Repository & Deployment Links

| Platform | Identifier |
|----------|------------|
| **GitHub** | https://github.com/nutbitzuist/ea-license-system |
| **Vercel Project ID** | `prj_wvR6HJH0GD6iIOw5WeI7dbkgVfRl` |
| **Railway Project ID** | `30198fc4-b023-4e7f-a973-e7871ff987a2` |

## CLI Commands Reference

### Link Vercel Project
```bash
vercel link --project prj_wvR6HJH0GD6iIOw5WeI7dbkgVfRl
```

### Link Railway Project
```bash
railway link 30198fc4-b023-4e7f-a973-e7871ff987a2
```

### Deploy to Vercel (Production)
```bash
vercel --prod --yes
```

### Deploy to Railway
```bash
railway up
```

## Full Deployment Flow
```bash
# 1. Push to GitHub
git add -A && git commit -m "your message" && git push origin main

# 2. Deploy to Vercel (auto-deploys from GitHub, but manual if needed)
vercel --prod --yes

# 3. Deploy to Railway
railway up
```
