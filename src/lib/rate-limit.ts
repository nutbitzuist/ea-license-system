// Simple in-memory rate limiter
// For production, consider using Redis or a similar solution

interface RateLimitEntry {
  count: number
  resetTime: number
}

const rateLimitStore = new Map<string, RateLimitEntry>()

export interface RateLimitConfig {
  maxRequests: number
  windowMs: number
}

export function checkRateLimit(
  key: string,
  config: RateLimitConfig = { maxRequests: 100, windowMs: 60000 }
): { allowed: boolean; remaining: number; resetTime: number } {
  const now = Date.now()
  const entry = rateLimitStore.get(key)

  // Clean up expired entries periodically
  if (Math.random() < 0.01) {
    cleanupExpiredEntries()
  }

  if (!entry || now > entry.resetTime) {
    // Create new entry
    const newEntry: RateLimitEntry = {
      count: 1,
      resetTime: now + config.windowMs,
    }
    rateLimitStore.set(key, newEntry)
    return {
      allowed: true,
      remaining: config.maxRequests - 1,
      resetTime: newEntry.resetTime,
    }
  }

  if (entry.count >= config.maxRequests) {
    return {
      allowed: false,
      remaining: 0,
      resetTime: entry.resetTime,
    }
  }

  entry.count++
  return {
    allowed: true,
    remaining: config.maxRequests - entry.count,
    resetTime: entry.resetTime,
  }
}

function cleanupExpiredEntries() {
  const now = Date.now()
  const keys = Array.from(rateLimitStore.keys())
  for (const key of keys) {
    const entry = rateLimitStore.get(key)
    if (entry && now > entry.resetTime) {
      rateLimitStore.delete(key)
    }
  }
}

// Rate limit configurations
export const RATE_LIMITS = {
  validation: { maxRequests: 100, windowMs: 60000 }, // 100 requests per minute
  api: { maxRequests: 60, windowMs: 60000 }, // 60 requests per minute
  auth: { maxRequests: 10, windowMs: 60000 }, // 10 auth attempts per minute
}
