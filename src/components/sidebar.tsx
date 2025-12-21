"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { cn } from "@/lib/utils"
import { ThemeToggle } from "@/components/theme-toggle"
import {
  LayoutDashboard,
  Users,
  Key,
  Bot,
  Settings,
  FileText,
  Shield,
  BarChart3,
  BookOpen,
  Activity,
  TrendingUp,
  Bell,
  Gift,
  MessageSquare,
} from "lucide-react"


const userNavItems = [
  {
    title: "Dashboard",
    href: "/dashboard",
    icon: LayoutDashboard,
  },
  {
    title: "Expert Advisors",
    href: "/downloads",
    icon: Bot,
  },
  {

    title: "Performance",
    href: "/performance",
    icon: TrendingUp,
  },
  {
    title: "License Usage",
    href: "/analytics",
    icon: Activity,
  },
  {
    title: "MT Accounts",
    href: "/accounts",
    icon: Users,
  },
  {
    title: "Notifications",
    href: "/notifications",
    icon: Bell,
  },
  {
    title: "Referrals",
    href: "/referrals",
    icon: Gift,
  },
  {
    title: "API Keys",
    href: "/api-keys",
    icon: Key,
  },
  {
    title: "Quick Start",
    href: "/guide",
    icon: BookOpen,
  },
  {
    title: "Contact",
    href: "/contact",
    icon: MessageSquare,
  },
  {
    title: "Settings",
    href: "/settings",
    icon: Settings,
  },
]

const adminNavItems = [
  {
    title: "Overview",
    href: "/admin",
    icon: BarChart3,
  },
  {
    title: "Users",
    href: "/admin/users",
    icon: Users,
  },
  {
    title: "Expert Advisors",
    href: "/admin/eas",
    icon: Bot,
  },
  {
    title: "Promo Codes",
    href: "/admin/promo-codes",
    icon: Gift,
  },
  {
    title: "Validation Logs",
    href: "/admin/logs",
    icon: FileText,
  },
]

interface SidebarProps {
  isAdmin?: boolean
}

export function Sidebar({ isAdmin = false }: SidebarProps) {
  const pathname = usePathname()
  const navItems = isAdmin ? adminNavItems : userNavItems

  return (
    <div className="flex h-full w-64 flex-col border-r bg-card">
      <div className="flex h-16 items-center border-b px-6">
        <Link href={isAdmin ? "/admin" : "/dashboard"} className="flex items-center gap-2">
          <Shield className="h-6 w-6 text-primary" />
          <span className="font-bold text-lg">My Algo Stack</span>
        </Link>
      </div>
      <nav className="flex-1 space-y-1 p-4">
        {navItems.map((item) => {
          const isActive = pathname === item.href ||
            (item.href !== "/dashboard" && item.href !== "/admin" && pathname.startsWith(item.href))
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                isActive
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
              )}
            >
              <item.icon className="h-4 w-4" />
              {item.title}
            </Link>
          )
        })}
      </nav>
      <div className="border-t p-4 space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-sm text-muted-foreground">Theme</span>
          <ThemeToggle />
        </div>
        {!isAdmin && (
          <Link
            href="/admin"
            className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors"
          >
            <Shield className="h-4 w-4" />
            Admin Panel
          </Link>
        )}
      </div>
    </div>
  )
}
