"use client"

import { useSession, signOut } from "next-auth/react"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { LogOut, User, Settings } from "lucide-react"
import Link from "next/link"

export function Navbar() {
  const { data: session } = useSession()

  const getInitials = (name: string) => {
    return name
      .split(" ")
      .map((n) => n[0])
      .join("")
      .toUpperCase()
      .slice(0, 2)
  }

  return (
    <header className="flex h-16 items-center justify-between bg-[var(--brutal-bg)] dark:bg-background border-b-[3px] border-[var(--brutal-border)] px-6">
      <div className="flex items-center gap-4">
        <h1 className="text-lg font-bold">My Algo Stack</h1>
      </div>
      <div className="flex items-center gap-4">
        {session?.user && (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" className="relative h-11 w-11 p-0 border-[3px] border-[var(--brutal-border)] brutal-shadow hover:brutal-shadow-sm hover:translate-x-[2px] hover:translate-y-[2px] transition-all rounded-none">
                <Avatar className="h-full w-full rounded-none">
                  <AvatarFallback className="rounded-none bg-[var(--brutal-green)] text-white font-bold">
                    {getInitials(session.user.name || "U")}
                  </AvatarFallback>
                </Avatar>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent className="w-56 border-[3px] border-[var(--brutal-border)] brutal-shadow rounded-none" align="end" forceMount>
              <DropdownMenuLabel className="font-normal">
                <div className="flex flex-col space-y-1">
                  <p className="text-sm font-bold leading-none">
                    {session.user.name}
                  </p>
                  <p className="text-xs leading-none text-muted-foreground">
                    {session.user.email}
                  </p>
                </div>
              </DropdownMenuLabel>
              <DropdownMenuSeparator className="bg-[var(--brutal-border)]" />
              <DropdownMenuItem asChild className="font-semibold cursor-pointer hover:bg-[var(--brutal-green-light)]">
                <Link href="/settings">
                  <User className="mr-2 h-4 w-4" />
                  Profile
                </Link>
              </DropdownMenuItem>
              <DropdownMenuItem asChild className="font-semibold cursor-pointer hover:bg-[var(--brutal-green-light)]">
                <Link href="/settings">
                  <Settings className="mr-2 h-4 w-4" />
                  Settings
                </Link>
              </DropdownMenuItem>
              <DropdownMenuSeparator className="bg-[var(--brutal-border)]" />
              <DropdownMenuItem
                className="font-semibold cursor-pointer text-destructive focus:text-destructive hover:bg-red-50 dark:hover:bg-red-950"
                onClick={() => signOut({ callbackUrl: "/login" })}
              >
                <LogOut className="mr-2 h-4 w-4" />
                Log out
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        )}
      </div>
    </header>
  )
}

