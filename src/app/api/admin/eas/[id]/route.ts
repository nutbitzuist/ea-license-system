import { NextRequest, NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { id } = await params

    const ea = await prisma.expertAdvisor.findUnique({
      where: { id },
      include: {
        _count: {
          select: { userAccess: true },
        },
      },
    })

    if (!ea) {
      return NextResponse.json({ error: "EA not found" }, { status: 404 })
    }

    return NextResponse.json({ ea })
  } catch (error) {
    console.error("Get EA error:", error)
    return NextResponse.json({ error: "Failed to fetch EA" }, { status: 500 })
  }
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id || session.user.role !== "ADMIN") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { id } = await params
    const body = await request.json()

    const ea = await prisma.expertAdvisor.update({
      where: { id },
      data: {
        name: body.name,
        description: body.description,
        currentVersion: body.currentVersion,
        isActive: body.isActive,
      },
    })

    return NextResponse.json({ ea })
  } catch (error) {
    console.error("Update EA error:", error)
    return NextResponse.json({ error: "Failed to update EA" }, { status: 500 })
  }
}
