/**
 * Structured Logger
 * Outputs JSON logs that Vercel parses automatically
 */

type LogLevel = "info" | "warn" | "error"

interface LogContext {
    userId?: string
    route?: string
    action?: string
    ip?: string
    duration?: number
    [key: string]: unknown
}

function sanitize(context?: LogContext): LogContext | undefined {
    if (!context) return undefined

    // Remove sensitive fields if accidentally passed
    const sanitized = { ...context }
    const sensitiveKeys = ["password", "token", "secret", "apiKey", "apiSecret", "cookie", "authorization"]

    for (const key of Object.keys(sanitized)) {
        if (sensitiveKeys.some(s => key.toLowerCase().includes(s))) {
            sanitized[key] = "[REDACTED]"
        }
    }

    return sanitized
}

function formatLog(level: LogLevel, message: string, context?: LogContext): string {
    return JSON.stringify({
        level,
        message,
        timestamp: new Date().toISOString(),
        ...sanitize(context),
    })
}

export const logger = {
    /**
     * Log informational message
     * @example logger.info("User logged in", { userId: "123", ip: "1.2.3.4" })
     */
    info: (message: string, context?: LogContext) => {
        console.log(formatLog("info", message, context))
    },

    /**
     * Log warning message
     * @example logger.warn("Rate limit approaching", { userId: "123", remaining: 5 })
     */
    warn: (message: string, context?: LogContext) => {
        console.warn(formatLog("warn", message, context))
    },

    /**
     * Log error message
     * @example logger.error("Trade submission failed", { userId: "123", error: err.message })
     */
    error: (message: string, context?: LogContext) => {
        console.error(formatLog("error", message, context))
    },
}

// Re-export for convenience
export type { LogContext }
