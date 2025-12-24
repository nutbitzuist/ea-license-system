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
  Layers,
  BarChart3,
  BookOpen,
  Activity,
  TrendingUp,
  Bell,
  Gift,
  MessageSquare,
  Settings2,
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
    <div className="flex h-full w-64 flex-col bg-[var(--brutal-bg)] dark:bg-background border-r-[3px] border-[var(--brutal-border)]">
      {/* Logo */}
      <div className="flex h-16 items-center border-b-[3px] border-[var(--brutal-border)] px-6">
        <Link href={isAdmin ? "/admin" : "/dashboard"} className="flex items-center gap-3 group">
          <div className="w-10 h-10 bg-[var(--brutal-green)] border-[3px] border-[var(--brutal-border)] flex items-center justify-center brutal-shadow group-hover:brutal-shadow-sm group-hover:translate-x-[2px] group-hover:translate-y-[2px] transition-all">
            <Layers className="h-5 w-5 text-white" />
          </div>
          <span className="font-bold text-lg">My Algo Stack</span>
        </Link>
      </div>
      
      {/* Navigation */}
      <nav className="flex-1 space-y-2 p-4 overflow-y-auto">
        {navItems.map((item) => {
          const isActive = pathname === item.href ||
            (item.href !== "/dashboard" && item.href !== "/admin" && pathname.startsWith(item.href))
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 px-4 py-3 text-sm font-semibold transition-all",
                isActive
                  ? "bg-[var(--brutal-green)] text-white border-[3px] border-[var(--brutal-border)] brutal-shadow"
                  : "text-muted-foreground hover:bg-[var(--brutal-green-light)] hover:text-foreground border-[3px] border-transparent hover:border-[var(--brutal-border)]"
              )}
            >
              <item.icon className="h-5 w-5" />
              {item.title}
            </Link>
          )
        })}
      </nav>
      
      {/* Footer */}
      <div className="border-t-[3px] border-[var(--brutal-border)] p-4 space-y-3">
        <div className="flex items-center justify-between px-2">
          <span className="text-sm font-semibold text-muted-foreground">Theme</span>
          <ThemeToggle />
        </div>
        {!isAdmin && (
          <Link
            href="/admin"
            className="flex items-center gap-3 px-4 py-3 text-sm font-semibold text-muted-foreground hover:bg-[var(--brutal-green-light)] hover:text-foreground border-[3px] border-transparent hover:border-[var(--brutal-border)] transition-all"
          >
            <Settings2 className="h-5 w-5" />
            Admin Panel
          </Link>
        )}
      </div>
    </div>
  )
}

