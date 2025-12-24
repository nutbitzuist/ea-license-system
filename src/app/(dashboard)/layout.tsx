import { redirect } from "next/navigation"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth"
import { Sidebar } from "@/components/sidebar"
import { Navbar } from "@/components/navbar"

// DEV BYPASS: Set to true to skip authentication (for local UI testing only)
const DEV_BYPASS = false

// Force dynamic rendering for authenticated routes
export const dynamic = "force-dynamic"

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  // DEV BYPASS: Skip auth check when enabled
  if (!DEV_BYPASS) {
    const session = await getServerSession(authOptions)
    if (!session?.user) {
      redirect("/login")
    }
  }

  return (
    <div className="flex h-screen">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Navbar />
        <main className="flex-1 overflow-y-auto bg-[var(--brutal-bg)] dark:bg-background p-6">
          {children}
        </main>
      </div>
    </div>
  )
}

