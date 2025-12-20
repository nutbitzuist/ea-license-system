import { Resend } from "resend"

// Lazy initialization to avoid build-time errors when RESEND_API_KEY is not set
let resendClient: Resend | null = null

function getResendClient(): Resend {
  if (!resendClient) {
    const apiKey = process.env.RESEND_API_KEY
    if (!apiKey) {
      throw new Error("RESEND_API_KEY environment variable is not set")
    }
    resendClient = new Resend(apiKey)
  }
  return resendClient
}

const APP_NAME = process.env.NEXT_PUBLIC_APP_NAME || "EA License System"
const APP_URL = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000"
const EMAIL_FROM = process.env.EMAIL_FROM || "noreply@myalgostack.com"

export async function sendPasswordResetEmail(email: string, token: string) {
  const resetUrl = `${APP_URL}/reset-password?token=${token}`

  try {
    await getResendClient().emails.send({
      from: EMAIL_FROM,
      to: email,
      subject: `Reset your ${APP_NAME} password`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 20px; background-color: #f5f5f5;">
          <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; padding: 40px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <h1 style="color: #1a1a1a; margin-bottom: 24px;">Reset Your Password</h1>
            <p style="color: #666; font-size: 16px; line-height: 1.5;">
              You requested a password reset for your ${APP_NAME} account.
            </p>
            <p style="color: #666; font-size: 16px; line-height: 1.5;">
              Click the button below to set a new password:
            </p>
            <div style="text-align: center; margin: 32px 0;">
              <a href="${resetUrl}" 
                 style="background-color: #3b82f6; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: 600; display: inline-block;">
                Reset Password
              </a>
            </div>
            <p style="color: #999; font-size: 14px;">
              This link will expire in 1 hour.
            </p>
            <p style="color: #999; font-size: 14px;">
              If you didn't request this, you can safely ignore this email.
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
    return { success: true }
  } catch (error) {
    console.error("Failed to send password reset email:", error)
    return { success: false, error }
  }
}

export async function sendVerificationEmail(email: string, token: string) {
  const verifyUrl = `${APP_URL}/api/auth/verify-email?token=${token}`

  try {
    await getResendClient().emails.send({
      from: EMAIL_FROM,
      to: email,
      subject: `Verify your ${APP_NAME} email`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 20px; background-color: #f5f5f5;">
          <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; padding: 40px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <h1 style="color: #1a1a1a; margin-bottom: 24px;">Verify Your Email</h1>
            <p style="color: #666; font-size: 16px; line-height: 1.5;">
              Welcome to ${APP_NAME}! Please verify your email address to complete your registration.
            </p>
            <div style="text-align: center; margin: 32px 0;">
              <a href="${verifyUrl}" 
                 style="background-color: #22c55e; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: 600; display: inline-block;">
                Verify Email
              </a>
            </div>
            <p style="color: #999; font-size: 14px;">
              This link will expire in 24 hours.
            </p>
            <p style="color: #999; font-size: 14px;">
              If you didn't create an account, you can safely ignore this email.
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
    return { success: true }
  } catch (error) {
    console.error("Failed to send verification email:", error)
    return { success: false, error }
  }
}

export function generateToken(): string {
  const array = new Uint8Array(32)
  crypto.getRandomValues(array)
  return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join("")
}
