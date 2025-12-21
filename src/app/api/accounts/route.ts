import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { accountSchema } from "@/lib/validations"
import { getMaxAccountsByTier } from "@/lib/utils"

export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const user = await prisma.user.findUnique({
      where: { id: session.user.id },
      select: { subscriptionTier: true },
    })

    const accounts = await prisma.mtAccount.findMany({
      where: {
        userId: session.user.id,
        deletedAt: null, // Exclude soft-deleted accounts
      },
      orderBy: { createdAt: "desc" },
    })


    const maxAccounts = getMaxAccountsByTier(user?.subscriptionTier || "TIER_1")

    return NextResponse.json({
      accounts,
      maxAccounts,
      usedSlots: accounts.length,
    })
  } catch (error) {
    console.error("Get accounts error:", error)
    return NextResponse.json({ error: "Failed to fetch accounts" }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const body = await request.json()
    const validatedData = accountSchema.parse(body)

    // Check user's account limit
    const user = await prisma.user.findUnique({
      where: { id: session.user.id },
      select: { subscriptionTier: true },
    })

    const currentAccountCount = await prisma.mtAccount.count({
      where: { userId: session.user.id },
    })

    const maxAccounts = getMaxAccountsByTier(user?.subscriptionTier || "TIER_1")

    if (currentAccountCount >= maxAccounts) {
      return NextResponse.json(
        { error: `Account limit reached. Maximum ${maxAccounts} accounts allowed for your tier.` },
        { status: 400 }
      )
    }

    // Check for duplicate account
    const existingAccount = await prisma.mtAccount.findFirst({
      where: {
        userId: session.user.id,
        accountNumber: validatedData.accountNumber,
        brokerName: validatedData.brokerName,
      },
    })

    if (existingAccount) {
      return NextResponse.json(
        { error: "This account is already registered" },
        { status: 400 }
      )
    }

    const account = await prisma.mtAccount.create({
      data: {
        userId: session.user.id,
        ...validatedData,
      },
    })

    return NextResponse.json({ account })
  } catch (error) {
    console.error("Create account error:", error)
    return NextResponse.json({ error: "Failed to create account" }, { status: 500 })
  }
}
