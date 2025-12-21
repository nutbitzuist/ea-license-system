import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { Resend } from "resend"
import { z } from "zod"

const contactSchema = z.object({
    issueType: z.enum(["bug", "feature", "billing", "account", "technical", "other"]),
    subject: z.string().min(5, "Subject must be at least 5 characters"),
    message: z.string().min(20, "Message must be at least 20 characters"),
})

const SUPPORT_EMAIL = "email.nutty@gmail.com"
const APP_NAME = process.env.NEXT_PUBLIC_APP_NAME || "My Algo Stack"

export async function POST(request: NextRequest) {
    try {
        const session = await getServerSession(authOptions)
        if (!session?.user?.id) {
            return NextResponse.json(
                { success: false, message: "You must be logged in to submit a request" },
                { status: 401 }
            )
        }

        const body = await request.json()
        const { issueType, subject, message } = contactSchema.parse(body)

        const apiKey = process.env.RESEND_API_KEY
        if (!apiKey) {
            console.error("RESEND_API_KEY not configured")
            return NextResponse.json(
                { success: false, message: "Email service not configured" },
                { status: 500 }
            )
        }

        const resend = new Resend(apiKey)

        const issueTypeLabels: Record<string, string> = {
            bug: "🐛 Bug Report",
            feature: "✨ Feature Request",
            billing: "💳 Billing Issue",
            account: "👤 Account Issue",
            technical: "🔧 Technical Support",
            other: "📝 Other",
        }

        await resend.emails.send({
            from: process.env.EMAIL_FROM || "noreply@myalgostack.com",
            to: SUPPORT_EMAIL,
            replyTo: session.user.email || undefined,
            subject: `[${APP_NAME}] ${issueTypeLabels[issueType]}: ${subject}`,
            html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 20px; background-color: #f5f5f5;">
          <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; padding: 40px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <h1 style="color: #1a1a1a; margin-bottom: 24px;">New Support Request</h1>
            
            <div style="margin-bottom: 20px;">
              <p style="color: #999; font-size: 14px; margin: 0;">Issue Type</p>
              <p style="color: #333; font-size: 16px; margin: 4px 0;">${issueTypeLabels[issueType]}</p>
            </div>
            
            <div style="margin-bottom: 20px;">
              <p style="color: #999; font-size: 14px; margin: 0;">From</p>
              <p style="color: #333; font-size: 16px; margin: 4px 0;">${session.user.name} (${session.user.email})</p>
            </div>
            
            <div style="margin-bottom: 20px;">
              <p style="color: #999; font-size: 14px; margin: 0;">Subject</p>
              <p style="color: #333; font-size: 16px; margin: 4px 0;">${subject}</p>
            </div>
            
            <div style="margin-bottom: 20px;">
              <p style="color: #999; font-size: 14px; margin: 0;">Message</p>
              <div style="color: #333; font-size: 16px; margin: 4px 0; white-space: pre-wrap; background: #f9f9f9; padding: 16px; border-radius: 8px;">${message}</div>
            </div>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
              Sent from ${APP_NAME} Dashboard
            </p>
          </div>
        </body>
        </html>
      `,
        })

        return NextResponse.json({
            success: true,
            message: "Your message has been sent. We'll get back to you soon!",
        })
    } catch (error) {
        console.error("Contact form error:", error)

        if (error instanceof z.ZodError) {
            return NextResponse.json(
                { success: false, message: error.issues[0]?.message || "Validation failed" },
                { status: 400 }
            )
        }

        return NextResponse.json(
            { success: false, message: "Failed to send message. Please try again." },
            { status: 500 }
        )
    }
}
