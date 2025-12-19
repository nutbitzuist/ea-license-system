import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { prisma } from "@/lib/db"
import { generateApiKey } from "@/lib/utils"

export async function POST() {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const newApiKey = generateApiKey()
    const newApiSecret = generateApiKey()

    const user = await prisma.user.update({
      where: { id: session.user.id },
      data: {
        apiKey: newApiKey,
        apiSecret: newApiSecret,
      },
      select: {
        apiKey: true,
        apiSecret: true,
      },
    })

    return NextResponse.json({
      apiKey: user.apiKey,
      apiSecret: user.apiSecret,
    })
  } catch (error) {
    console.error("Regenerate credentials error:", error)
    return NextResponse.json({ error: "Failed to regenerate credentials" }, { status: 500 })
  }
}
