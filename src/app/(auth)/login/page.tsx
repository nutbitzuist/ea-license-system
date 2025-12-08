"use client"

import { useState } from "react"
import { signIn } from "next-auth/react"
import { useRouter } from "next/navigation"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Shield, Loader2 } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

export default function LoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const router = useRouter()
  const { toast } = useToast()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    setError(null)

    try {
      console.log("Attempting login for:", email)
      
      const result = await signIn("credentials", {
        email,
        password,
        redirect: false,
      })

      console.log("SignIn result:", result)

      if (result?.error) {
        console.error("Login error:", result.error)
        setError("Invalid email or password")
        toast({
          title: "Error",
          description: "Invalid email or password",
          variant: "destructive",
        })
      } else if (result?.ok) {
        console.log("Login successful, redirecting...")
        router.push("/dashboard")
        router.refresh()
      } else {
        console.error("Unexpected result:", result)
        setError("Login failed. Please try again.")
      }
    } catch (err) {
      console.error("Login exception:", err)
      setError("Something went wrong. Please try again.")
      toast({
        title: "Error",
        description: "Something went wrong. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Card className="border-slate-700 bg-slate-800/50 backdrop-blur">
      <CardHeader className="space-y-1 text-center">
        <div className="flex justify-center mb-4">
          <div className="rounded-full bg-primary/10 p-3">
            <Shield className="h-8 w-8 text-primary" />
          </div>
        </div>
        <CardTitle className="text-2xl text-white">Welcome back</CardTitle>
        <CardDescription className="text-slate-400">
          Sign in to your EA License account
        </CardDescription>
      </CardHeader>
      <form onSubmit={handleSubmit}>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email" className="text-slate-200">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder="name@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="bg-slate-700/50 border-slate-600 text-white placeholder:text-slate-400"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password" className="text-slate-200">Password</Label>
            <Input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="bg-slate-700/50 border-slate-600 text-white"
            />
          </div>
          {error && (
            <div className="p-3 rounded-md bg-red-500/10 border border-red-500/50 text-red-400 text-sm">
              {error}
            </div>
          )}
        </CardContent>
        <CardFooter className="flex flex-col space-y-4">
          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Sign In
          </Button>
          <p className="text-sm text-slate-400 text-center">
            Don&apos;t have an account?{" "}
            <Link href="/register" className="text-primary hover:underline">
              Register
            </Link>
          </p>
        </CardFooter>
      </form>
    </Card>
  )
}
