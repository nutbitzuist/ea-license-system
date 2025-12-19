import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const sevenDaysAgo = new Date()
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)

    const [
      totalUsers,
      approvedUsers,
      pendingUsers,
      totalEas,
      totalAccounts,
      validationsToday,
      validationsByEa,
      recentPendingUsers,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { isApproved: true } }),
      prisma.user.count({ where: { isApproved: false } }),
      prisma.expertAdvisor.count(),
      prisma.mtAccount.count(),
      prisma.validationLog.count({
        where: { createdAt: { gte: today } },
      }),
      prisma.validationLog.groupBy({
        by: ["eaCode"],
        _count: true,
        where: { createdAt: { gte: sevenDaysAgo } },
        orderBy: { _count: { eaCode: "desc" } },
        take: 10,
      }),
      prisma.user.findMany({
        where: { isApproved: false },
        orderBy: { createdAt: "desc" },
        take: 5,
        select: {
          id: true,
          name: true,
          email: true,
          createdAt: true,
        },
      }),
    ])

    return NextResponse.json({
      totalUsers,
      approvedUsers,
      pendingUsers,
      totalEas,
      totalAccounts,
      validationsToday,
      validationsByEa,
      recentPendingUsers,
    })
  } catch (error) {
    console.error("Admin stats error:", error)
    return NextResponse.json({ error: "Failed to fetch stats" }, { status: 500 })
  }
}
