import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"
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

    const [accountsCount, easCount, validationsToday, recentValidations] = await Promise.all([
      prisma.mtAccount.count({
        where: { userId: session.user.id },
      }),
      prisma.userEaAccess.count({
        where: {
          userId: session.user.id,
          isEnabled: true,
          OR: [
            { expiresAt: null },
            { expiresAt: { gt: new Date() } },
          ],
        },
      }),
      prisma.validationLog.count({
        where: {
          userId: session.user.id,
          createdAt: {
            gte: new Date(new Date().setHours(0, 0, 0, 0)),
          },
        },
      }),
      prisma.validationLog.findMany({
        where: { userId: session.user.id },
        orderBy: { createdAt: "desc" },
        take: 5,
        select: {
          id: true,
          eaCode: true,
          accountNumber: true,
          result: true,
          createdAt: true,
        },
      }),
    ])

    return NextResponse.json({
      accountsUsed: accountsCount,
      maxAccounts: getMaxAccountsByTier(user?.subscriptionTier || "TIER_1"),
      easAccess: easCount,
      validationsToday,
      subscriptionTier: user?.subscriptionTier,
      recentValidations,
    })
  } catch (error) {
    console.error("Dashboard stats error:", error)
    return NextResponse.json({ error: "Failed to fetch stats" }, { status: 500 })
  }
}
