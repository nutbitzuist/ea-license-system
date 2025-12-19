import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const searchParams = request.nextUrl.searchParams
    const search = searchParams.get("search") || ""
    const result = searchParams.get("result")
    const page = parseInt(searchParams.get("page") || "1")
    const pageSize = 20

    const where: Record<string, unknown> = {}

    if (search) {
      where.OR = [
        { accountNumber: { contains: search, mode: "insensitive" } },
        { brokerName: { contains: search, mode: "insensitive" } },
        { eaCode: { contains: search, mode: "insensitive" } },
      ]
    }

    if (result && result !== "all") {
      where.result = result
    }

    const [logs, total] = await Promise.all([
      prisma.validationLog.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: {
          user: {
            select: {
              name: true,
              email: true,
            },
          },
        },
      }),
      prisma.validationLog.count({ where }),
    ])

    return NextResponse.json({
      logs,
      total,
      page,
      pageSize,
    })
  } catch (error) {
    console.error("Get logs error:", error)
    return NextResponse.json({ error: "Failed to fetch logs" }, { status: 500 })
  }
}
