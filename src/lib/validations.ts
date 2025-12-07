import { z } from "zod"

export const registerSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
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

export type RegisterInput = z.infer<typeof registerSchema>
export type LoginInput = z.infer<typeof loginSchema>
export type AccountInput = z.infer<typeof accountSchema>
export type ValidateLicenseInput = z.infer<typeof validateLicenseSchema>
export type CreateEaInput = z.infer<typeof createEaSchema>
export type UpdateUserInput = z.infer<typeof updateUserSchema>
export type GrantEaAccessInput = z.infer<typeof grantEaAccessSchema>
