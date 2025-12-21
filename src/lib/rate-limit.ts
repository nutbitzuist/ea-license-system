// Distributed rate limiter using Vercel KV
// Falls back to in-memory for local development

import { kv } from "@vercel/kv"

export interface RateLimitConfig {
  maxRequests: number
  windowMs: number
}

export interface RateLimitResult {
  allowed: boolean
  remaining: number
  resetTime: number
}

// In-memory fallback for local development
interface RateLimitEntry {
  count: number
  resetTime: number
}
const memoryStore = new Map<string, RateLimitEntry>()

/**
 * Check rate limit using Vercel KV (production) or in-memory (development)
 */
export async function checkRateLimitAsync(
  key: string,
  config: RateLimitConfig = { maxRequests: 100, windowMs: 60000 }
): Promise<RateLimitResult> {
  // Use Vercel KV in production
  if (process.env.KV_REST_API_URL && process.env.KV_REST_API_TOKEN) {
    return checkRateLimitKV(key, config)
  }
  // Fallback to in-memory for local dev
  return checkRateLimitMemory(key, config)
}

/**
 * Synchronous rate limit check (for backward compatibility)
 * Uses in-memory store only - suitable for development or non-critical paths
 */
export function checkRateLimit(
  key: string,
  config: RateLimitConfig = { maxRequests: 100, windowMs: 60000 }
): RateLimitResult {
  return checkRateLimitMemory(key, config)
}

async function checkRateLimitKV(
  key: string,
  config: RateLimitConfig
): Promise<RateLimitResult> {
  try {
    const now = Date.now()
    const windowKey = `ratelimit:${key}:${Math.floor(now / config.windowMs)}`

    // Increment counter
    const count = await kv.incr(windowKey)

    // Set expiry on first request of window
    if (count === 1) {
      await kv.expire(windowKey, Math.ceil(config.windowMs / 1000) + 1)
    }

    const resetTime = (Math.floor(now / config.windowMs) + 1) * config.windowMs

    return {
      allowed: count <= config.maxRequests,
      remaining: Math.max(0, config.maxRequests - count),
      resetTime,
    }
  } catch (error) {
    console.error("Vercel KV rate limit error:", error)
    // Fail open - allow request if KV is unavailable
    return {
      allowed: true,
      remaining: config.maxRequests,
      resetTime: Date.now() + config.windowMs,
    }
  }
}

function checkRateLimitMemory(
  key: string,
  config: RateLimitConfig
): RateLimitResult {
  const now = Date.now()
  const entry = memoryStore.get(key)

  // Clean up expired entries periodically (1% chance per request)
  if (Math.random() < 0.01) {
    const entries = Array.from(memoryStore.entries())
    for (const [k, v] of entries) {
      if (now > v.resetTime) memoryStore.delete(k)
    }
  }


  if (!entry || now > entry.resetTime) {
    const newEntry: RateLimitEntry = {
      count: 1,
      resetTime: now + config.windowMs,
    }
    memoryStore.set(key, newEntry)
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

// Rate limit configurations
export const RATE_LIMITS = {
  validation: { maxRequests: 100, windowMs: 60000 }, // 100 requests per minute
  api: { maxRequests: 60, windowMs: 60000 }, // 60 requests per minute
  auth: { maxRequests: 10, windowMs: 60000 }, // 10 auth attempts per minute
}
