import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { hash } from "bcryptjs"
import { Resend } from "resend"
import { z } from "zod"

const createUserSchema = z.object({
    name: z.string().min(2, "Name must be at least 2 characters"),
    email: z.string().email("Invalid email address"),
    subscriptionTier: z.enum(["TIER_1", "TIER_2", "TIER_3"]).default("TIER_1"),
    sendWelcomeEmail: z.boolean().default(true),
})

const APP_NAME = process.env.NEXT_PUBLIC_APP_NAME || "My Algo Stack"
const APP_URL = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000"

function generateTemporaryPassword(): string {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"
    let password = ""
    for (let i = 0; i < 12; i++) {
        password += chars.charAt(Math.floor(Math.random() * chars.length))
    }
    return password
}

function generateToken(): string {
    const array = new Uint8Array(32)
    crypto.getRandomValues(array)
    return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join("")
}

export async function POST(request: NextRequest) {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id || session.user.role !== "ADMIN") {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
        }

        const body = await request.json()
        const { name, email, subscriptionTier, sendWelcomeEmail } = createUserSchema.parse(body)

        // Check if user already exists
        const existingUser = await prisma.user.findUnique({
            where: { email },
        })

        if (existingUser) {
            return NextResponse.json(
                { error: "A user with this email already exists" },
                { status: 400 }
            )
        }

        // Generate temporary password and hash it
        const tempPassword = generateTemporaryPassword()
        const passwordHash = await hash(tempPassword, 12)

        // Calculate trial end date (14 days from now)
        const trialEndsAt = new Date()
        trialEndsAt.setDate(trialEndsAt.getDate() + 14)

        // Create user - auto-approved and email verified since admin is creating
        const user = await prisma.user.create({
            data: {
                name,
                email,
                passwordHash,
                subscriptionTier,
                isApproved: true,
                isActive: true,
                emailVerified: new Date(),
                trialEndsAt,
            },
            select: {
                id: true,
                email: true,
                name: true,
                subscriptionTier: true,
            },
        })

        // Send welcome email with password reset link
        if (sendWelcomeEmail) {
            const apiKey = process.env.RESEND_API_KEY
            if (apiKey) {
                const resend = new Resend(apiKey)

                // Create password reset token
                const resetToken = generateToken()
                const expiresAt = new Date()
                expiresAt.setHours(expiresAt.getHours() + 72) // 72 hours for new account setup

                await prisma.passwordResetToken.create({
                    data: {
                        email,
                        token: resetToken,
                        expiresAt,
                    },
                })

                const resetUrl = `${APP_URL}/reset-password?token=${resetToken}`

                await resend.emails.send({
                    from: process.env.EMAIL_FROM || "noreply@myalgostack.com",
                    to: email,
                    subject: `Welcome to ${APP_NAME} - Set Up Your Account`,
                    html: `
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
            </head>
            <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 20px; background-color: #f5f5f5;">
              <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; padding: 40px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                <h1 style="color: #1a1a1a; margin-bottom: 24px;">Welcome to ${APP_NAME}!</h1>
                <p style="color: #666; font-size: 16px; line-height: 1.5;">
                  Hi ${name},
                </p>
                <p style="color: #666; font-size: 16px; line-height: 1.5;">
                  An account has been created for you. To get started, please set up your password by clicking the button below:
                </p>
                <div style="text-align: center; margin: 32px 0;">
                  <a href="${resetUrl}" 
                     style="background-color: #3b82f6; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: 600; display: inline-block;">
                    Set Up Password
                  </a>
                </div>
                <p style="color: #666; font-size: 16px; line-height: 1.5;">
                  Your account includes a 14-day free trial with access to all Expert Advisors.
                </p>
                <p style="color: #999; font-size: 14px;">
                  This link will expire in 72 hours.
                </p>
                <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;">
                <p style="color: #999; font-size: 12px; text-align: center;">
                  © ${new Date().getFullYear()} ${APP_NAME}
                </p>
              </div>
            </body>
            </html>
          `,
                })
            }
        }

        return NextResponse.json({
            success: true,
            message: sendWelcomeEmail
                ? `User created and welcome email sent to ${email}`
                : `User created successfully`,
            user,
        })
    } catch (error) {
        console.error("Create user error:", error)

        if (error instanceof z.ZodError) {
            return NextResponse.json(
                { error: error.issues[0]?.message || "Validation failed" },
                { status: 400 }
            )
        }

        return NextResponse.json(
            { error: "Failed to create user" },
            { status: 500 }
        )
    }
}
