import { NextRequest, NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import { validateLicenseSchema } from "@/lib/validations"
import { checkRateLimit, RATE_LIMITS } from "@/lib/rate-limit"

export async function POST(request: NextRequest) {
  try {
    const apiKey = request.headers.get("X-API-Key")

    if (!apiKey) {
      return NextResponse.json(
        { valid: false, message: "Missing API Key", errorCode: "INVALID_CREDENTIALS" },
        { status: 401 }
      )
    }

    // Rate limiting by API key
    const rateLimitResult = checkRateLimit(`validate:${apiKey}`, RATE_LIMITS.validation)
    if (!rateLimitResult.allowed) {
      return NextResponse.json(
        {
          valid: false,
          message: "Rate limit exceeded. Please try again later.",
          errorCode: "RATE_LIMIT_EXCEEDED",
          retryAfter: Math.ceil((rateLimitResult.resetTime - Date.now()) / 1000)
        },
        {
          status: 429,
          headers: {
            "X-RateLimit-Remaining": rateLimitResult.remaining.toString(),
            "X-RateLimit-Reset": rateLimitResult.resetTime.toString(),
          }
        }
      )
    }

    // Find user by API key
    const user = await prisma.user.findUnique({
      where: { apiKey },
    })

    if (!user) {
      return NextResponse.json(
        { valid: false, message: "Invalid API Key", errorCode: "INVALID_CREDENTIALS" },
        { status: 401 }
      )
    }

    // Check if user is approved
    if (!user.isApproved) {
      await logValidation(user.id, null, null, request, "FAILED", "USER_NOT_APPROVED")
      return NextResponse.json(
        { valid: false, message: "User not approved", errorCode: "USER_NOT_APPROVED" },
        { status: 403 }
      )
    }

    // Check if user is active
    if (!user.isActive) {
      await logValidation(user.id, null, null, request, "FAILED", "USER_INACTIVE")
      return NextResponse.json(
        { valid: false, message: "User account inactive", errorCode: "USER_INACTIVE" },
        { status: 403 }
      )
    }

    // Parse and validate request body
    const body = await request.json()
    const validatedData = validateLicenseSchema.parse(body)

    // Find the EA
    const ea = await prisma.expertAdvisor.findUnique({
      where: { eaCode: validatedData.eaCode },
    })

    if (!ea) {
      await logValidation(user.id, null, null, request, "FAILED", "EA_NOT_FOUND", validatedData)
      return NextResponse.json(
        { valid: false, message: "EA not found", errorCode: "EA_NOT_FOUND" },
        { status: 404 }
      )
    }

    if (!ea.isActive) {
      await logValidation(user.id, null, ea.id, request, "FAILED", "EA_INACTIVE", validatedData)
      return NextResponse.json(
        { valid: false, message: "EA is inactive", errorCode: "EA_INACTIVE" },
        { status: 403 }
      )
    }

    // Check user's EA access
    const eaAccess = await prisma.userEaAccess.findFirst({
      where: {
        userId: user.id,
        eaId: ea.id,
        isEnabled: true,
      },
    })

    if (!eaAccess) {
      await logValidation(user.id, null, ea.id, request, "FAILED", "EA_ACCESS_DENIED", validatedData)
      return NextResponse.json(
        { valid: false, message: "No access to this EA", errorCode: "EA_ACCESS_DENIED" },
        { status: 403 }
      )
    }

    // Check if access has expired
    if (eaAccess.expiresAt && eaAccess.expiresAt < new Date()) {
      await logValidation(user.id, null, ea.id, request, "FAILED", "EA_ACCESS_EXPIRED", validatedData)
      return NextResponse.json(
        { valid: false, message: "EA access has expired", errorCode: "EA_ACCESS_EXPIRED" },
        { status: 403 }
      )
    }

    // Find the MT account - match by account number only (broker name can vary)
    const mtAccount = await prisma.mtAccount.findFirst({
      where: {
        userId: user.id,
        accountNumber: validatedData.accountNumber,
      },
    })

    if (!mtAccount) {
      await logValidation(user.id, null, ea.id, request, "FAILED", "ACCOUNT_NOT_FOUND", validatedData)
      return NextResponse.json(
        { valid: false, message: "Account not registered. Add account " + validatedData.accountNumber + " in your dashboard first.", errorCode: "ACCOUNT_NOT_FOUND" },
        { status: 403 }
      )
    }

    if (!mtAccount.isActive) {
      await logValidation(user.id, mtAccount.id, ea.id, request, "FAILED", "ACCOUNT_INACTIVE", validatedData)
      return NextResponse.json(
        { valid: false, message: "Account is inactive", errorCode: "ACCOUNT_INACTIVE" },
        { status: 403 }
      )
    }

    // Update last validated timestamp
    await prisma.mtAccount.update({
      where: { id: mtAccount.id },
      data: { lastValidatedAt: new Date() },
    })

    // Log successful validation
    await logValidation(user.id, mtAccount.id, ea.id, request, "SUCCESS", null, validatedData)

    return NextResponse.json({
      valid: true,
      message: "License valid",
      gracePeriodHours: 24,
      serverTime: new Date().toISOString(),
    })
  } catch (error) {
    console.error("Validation error:", error)
    return NextResponse.json(
      { valid: false, message: "Validation failed", errorCode: "SERVER_ERROR" },
      { status: 500 }
    )
  }
}

async function logValidation(
  userId: string,
  mtAccountId: string | null,
  eaId: string | null,
  request: NextRequest,
  result: "SUCCESS" | "FAILED",
  failureReason: string | null,
  data?: {
    accountNumber: string
    brokerName: string
    eaCode: string
    eaVersion: string
    terminalType: "MT4" | "MT5"
  }
) {
  try {
    const ipAddress = request.headers.get("x-forwarded-for") ||
      request.headers.get("x-real-ip") ||
      "unknown"

    await prisma.validationLog.create({
      data: {
        userId,
        mtAccountId,
        eaId,
        accountNumber: data?.accountNumber || "unknown",
        brokerName: data?.brokerName || "unknown",
        terminalType: data?.terminalType || "MT5",
        eaCode: data?.eaCode || "unknown",
        eaVersion: data?.eaVersion || "unknown",
        ipAddress,
        result,
        failureReason,
      },
    })
  } catch (error) {
    console.error("Failed to log validation:", error)
  }
}
