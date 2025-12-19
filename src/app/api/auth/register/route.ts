import { NextRequest, NextResponse } from "next/server"
import { hash } from "bcryptjs"
import { prisma } from "@/lib/db"
import { registerSchema } from "@/lib/validations"
import { z } from "zod"

// Extended schema with optional referral code
const registerWithReferralSchema = registerSchema.extend({
  referralCode: z.string().optional(),
})

export async function POST(request: NextRequest) {
  try {
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

    // Create user with 14-day free trial (auto-approved)
    const user = await prisma.user.create({
      data: {
        email: validatedData.email,
        passwordHash,
        name: validatedData.name,
        isApproved: true,  // Auto-approve for free trial
        trialEndsAt,       // 14-day trial
        referredByCode: validatedData.referralCode || null,
      },
    })

    // Create referral record if referred by someone
    if (referrerId) {
      await prisma.referral.create({
        data: {
          referrerId,
          referredId: user.id,
          referralCode: validatedData.referralCode!,
          status: "PENDING",
        },
      })
    }

    return NextResponse.json({
      success: true,
      message: "Welcome to My Algo Stack! Your 14-day free trial has started.",
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
