import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { createEaSchema } from "@/lib/validations"

export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const eas = await prisma.expertAdvisor.findMany({
      orderBy: { createdAt: "desc" },
      include: {
        _count: {
          select: { userAccess: true },
        },
      },
    })

    return NextResponse.json({ eas })
  } catch (error) {
    console.error("Get EAs error:", error)
    return NextResponse.json({ error: "Failed to fetch EAs" }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const body = await request.json()
    const validatedData = createEaSchema.parse(body)

    // Check if EA code already exists
    const existingEa = await prisma.expertAdvisor.findUnique({
      where: { eaCode: validatedData.eaCode },
    })

    if (existingEa) {
      return NextResponse.json({ error: "EA code already exists" }, { status: 400 })
    }

    const ea = await prisma.expertAdvisor.create({
      data: validatedData,
    })

    return NextResponse.json({ ea })
  } catch (error) {
    console.error("Create EA error:", error)
    return NextResponse.json({ error: "Failed to create EA" }, { status: 500 })
  }
}
