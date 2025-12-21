import { NextRequest, NextResponse } from "next/server"
import { hash } from "bcryptjs"
import { prisma } from "@/lib/db"
import { Prisma } from "@prisma/client"
import { registerSchema } from "@/lib/validations"
import { sendVerificationEmail, generateToken } from "@/lib/email"
import { checkRateLimit, RATE_LIMITS } from "@/lib/rate-limit"
import { z } from "zod"


// Extended schema with optional referral code and promo code
const registerWithCodesSchema = registerSchema.extend({
  referralCode: z.string().optional(),
  promoCode: z.string().optional(),
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
    const validatedData = registerWithCodesSchema.parse(body)


    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: validatedData.email },
    })

    if (existingUser) {
      // If user exists but not verified, suggest checking email
      if (!existingUser.emailVerified) {
        return NextResponse.json(
          {
            error: "This email is already registered but not verified. Please check your inbox for the verification link.",
            canResend: true,
          },
          { status: 400 }
        )
      }
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

    // Validate promo code if provided
    let promoCodeData: {
      id: string
      daysGranted: number
      subscriptionTier: string | null
    } | null = null

    if (validatedData.promoCode) {
      const promoCode = await prisma.promoCode.findUnique({
        where: { code: validatedData.promoCode.toUpperCase() },
      })

      if (promoCode) {
        // Check if promo code is valid
        const now = new Date()
        const isExpired = promoCode.expiresAt && promoCode.expiresAt < now
        const isMaxedOut = promoCode.maxUsages > 0 && promoCode.currentUsages >= promoCode.maxUsages

        if (promoCode.isActive && !isExpired && !isMaxedOut) {
          promoCodeData = {
            id: promoCode.id,
            daysGranted: promoCode.daysGranted,
            subscriptionTier: promoCode.subscriptionTier,
          }
        }
      }
    }

    // Hash password
    const passwordHash = await hash(validatedData.password, 12)

    // Calculate trial end date (14 days from now + promo bonus)
    const trialEndsAt = new Date()
    const baseDays = 14
    const bonusDays = promoCodeData?.daysGranted || 0
    trialEndsAt.setDate(trialEndsAt.getDate() + baseDays + bonusDays)

    // Determine subscription tier
    const subscriptionTier = promoCodeData?.subscriptionTier as "TIER_1" | "TIER_2" | "TIER_3" | undefined

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
          trialEndsAt,       // 14-day trial + bonus
          emailVerified: null, // Not verified yet
          referredByCode: validatedData.referralCode || null,
          subscriptionTier: subscriptionTier || "TIER_1",
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

      // Record promo code usage if used
      if (promoCodeData) {
        await tx.promoCodeUsage.create({
          data: {
            promoCodeId: promoCodeData.id,
            userId: newUser.id,
          },
        })

        // Increment usage counter
        await tx.promoCode.update({
          where: { id: promoCodeData.id },
          data: { currentUsages: { increment: 1 } },
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

    // Build success message
    let message = "Welcome to My Algo Stack! Please check your email to verify your account."
    if (promoCodeData) {
      if (promoCodeData.daysGranted > 0) {
        message = `Welcome! Your promo code added ${promoCodeData.daysGranted} bonus days to your trial. Please verify your email.`
      }
    }

    return NextResponse.json({
      success: true,
      message,
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
