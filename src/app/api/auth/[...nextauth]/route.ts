import { handlers } from "@/lib/auth"

// Force Node.js runtime for Prisma compatibility
export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export const { GET, POST } = handlers
