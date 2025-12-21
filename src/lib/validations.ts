import { z } from "zod"

export const registerSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(8, "Password must be at least 8 characters").max(128, "Password too long"),
  name: z.string().min(2, "Name must be at least 2 characters"),
})


export const loginSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(1, "Password is required"),
})

export const accountSchema = z.object({
  accountNumber: z.string().min(1, "Account number is required"),
  brokerName: z.string().min(1, "Broker name is required"),
  accountType: z.enum(["DEMO", "LIVE"]),
  terminalType: z.enum(["MT4", "MT5"]),
  nickname: z.string().optional(),
})

export const validateLicenseSchema = z.object({
  accountNumber: z.string().min(1, "Account number is required"),
  brokerName: z.string().min(1, "Broker name is required"),
  eaCode: z.string().min(1, "EA code is required"),
  eaVersion: z.string().min(1, "EA version is required"),
  terminalType: z.enum(["MT4", "MT5"]),
})

export const createEaSchema = z.object({
  eaCode: z.string().min(1, "EA code is required").regex(/^[a-z0-9_]+$/, "EA code must be lowercase alphanumeric with underscores"),
  name: z.string().min(1, "Name is required"),
  description: z.string().optional(),
  currentVersion: z.string().min(1, "Version is required"),
})

export const updateUserSchema = z.object({
  isApproved: z.boolean().optional(),
  isActive: z.boolean().optional(),
  subscriptionTier: z.enum(["TIER_1", "TIER_2", "TIER_3"]).optional(),
  role: z.enum(["USER", "ADMIN"]).optional(),
})

export const grantEaAccessSchema = z.object({
  eaId: z.string().min(1, "EA ID is required"),
  expiresAt: z.string().datetime().optional().nullable(),
})

// Trade submission from EA (open or close)
export const tradeSubmitSchema = z.object({
  accountNumber: z.string().min(1, "Account number is required"),
  ticket: z.number().int().positive("Ticket must be positive"),
  symbol: z.string().min(1, "Symbol is required"),
  type: z.enum(["BUY", "SELL"]),
  lots: z.number().positive("Lots must be positive"),
  openPrice: z.number().positive("Open price is required"),
  closePrice: z.number().optional(),
  stopLoss: z.number().optional(),
  takeProfit: z.number().optional(),
  openTime: z.string().datetime(),
  closeTime: z.string().datetime().optional(),
  profit: z.number().optional(),
  pips: z.number().optional(),
  swap: z.number().optional(),
  commission: z.number().optional(),
  status: z.enum(["OPEN", "CLOSED"]),
  eaCode: z.string().optional(),
})

// Notification settings update
export const notificationSettingsSchema = z.object({
  telegramChatId: z.string().optional().nullable(),
  discordWebhook: z.string().url().optional().nullable(),
  notifyTradeOpen: z.boolean().optional(),
  notifyTradeClose: z.boolean().optional(),
  notifyDailyPL: z.boolean().optional(),
  notifyDrawdown: z.boolean().optional(),
  drawdownThreshold: z.number().min(1).max(100).optional(),
  dailySummaryTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).optional(),
})

export type RegisterInput = z.infer<typeof registerSchema>
export type LoginInput = z.infer<typeof loginSchema>
export type AccountInput = z.infer<typeof accountSchema>
export type ValidateLicenseInput = z.infer<typeof validateLicenseSchema>
export type CreateEaInput = z.infer<typeof createEaSchema>
export type UpdateUserInput = z.infer<typeof updateUserSchema>
export type GrantEaAccessInput = z.infer<typeof grantEaAccessSchema>
export type TradeSubmitInput = z.infer<typeof tradeSubmitSchema>
export type NotificationSettingsInput = z.infer<typeof notificationSettingsSchema>

