import { NextResponse } from "next/server"
import { auth } from "@/lib/auth"
import { prisma } from "@/lib/db"

export async function GET() {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const user = await prisma.user.findUnique({
      where: { id: session.user.id },
      select: {
        apiKey: true,
        apiSecret: true,
      },
    })

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 })
    }

    return NextResponse.json({
      apiKey: user.apiKey,
      apiSecret: user.apiSecret,
    })
  } catch (error) {
    console.error("Get credentials error:", error)
    return NextResponse.json({ error: "Failed to fetch credentials" }, { status: 500 })
  }
}
