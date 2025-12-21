import { NextRequest, NextResponse } from "next/server"
import { hash } from "bcryptjs"
import { prisma } from "@/lib/db"
import { Prisma } from "@prisma/client"
import { registerSchema } from "@/lib/validations"
import { sendVerificationEmail, generateToken } from "@/lib/email"
import { checkRateLimit, RATE_LIMITS } from "@/lib/rate-limit"
import { z } from "zod"


// Extended schema with optional referral code
const registerWithReferralSchema = registerSchema.extend({
  referralCode: z.string().optional(),
})

export async function POST(request: NextRequest) {
  try {
    // Rate limiting by IP
    const ip = request.headers.get("x-forwarded-for") || request.headers.get("x-real-ip") || "unknown"
    const rateLimitResult = checkRateLimit(`auth:register:${ip}`, RATE_LIMITS.auth)
    if (!rateLimitResult.allowed) {
      return NextResponse.json(
        { error: "Too many registration attempts. Please try again later." },
        { status: 429 }
      )
    }

    const body = await request.json()
    const validatedData = registerWithReferralSchema.parse(body)


    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: validatedData.email },
    })

    if (existingUser) {
      return NextResponse.json(
        { error: "Email already registered" },
        { status: 400 }
      )
    }

    // Find referrer if referral code provided
    let referrerId: string | null = null
    if (validatedData.referralCode) {
      const referrer = await prisma.user.findUnique({
        where: { referralCode: validatedData.referralCode },
      })
      if (referrer) {
        referrerId = referrer.id
      }
    }

    // Hash password
    const passwordHash = await hash(validatedData.password, 12)

    // Calculate trial end date (14 days from now)
    const trialEndsAt = new Date()
    trialEndsAt.setDate(trialEndsAt.getDate() + 14)

    // Generate email verification token
    const token = generateToken()
    const tokenExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours

    // Use transaction to ensure all records are created atomically
    const user = await prisma.$transaction(async (tx: Prisma.TransactionClient) => {

      // Create user with 14-day free trial (auto-approved)
      const newUser = await tx.user.create({
        data: {
          email: validatedData.email,
          passwordHash,
          name: validatedData.name,
          isApproved: true,  // Auto-approve for free trial
          trialEndsAt,       // 14-day trial
          emailVerified: null, // Not verified yet
          referredByCode: validatedData.referralCode || null,
        },
      })

      // Create referral record if referred by someone
      if (referrerId) {
        await tx.referral.create({
          data: {
            referrerId,
            referredId: newUser.id,
            referralCode: validatedData.referralCode!,
            status: "PENDING",
          },
        })
      }

      // Create email verification token
      await tx.emailVerificationToken.create({
        data: {
          email: validatedData.email,
          token,
          expiresAt: tokenExpiresAt,
        },
      })

      return newUser
    })


    // Send verification email (non-blocking)
    sendVerificationEmail(validatedData.email, token).catch(console.error)

    return NextResponse.json({
      success: true,
      message: "Welcome to My Algo Stack! Please check your email to verify your account.",
      userId: user.id,
    })
  } catch (error) {
    console.error("Registration error:", error)
    return NextResponse.json(
      { error: "Registration failed" },
      { status: 500 }
    )
  }
}
