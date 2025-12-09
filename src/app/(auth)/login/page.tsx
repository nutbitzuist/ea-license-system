import Link from "next/link"
import { signIn } from "@/lib/auth"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Shield } from "lucide-react"

interface LoginPageProps {
  searchParams?: {
    error?: string
  }
}

export default function LoginPage({ searchParams }: LoginPageProps) {
  const error = searchParams?.error

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
      <form
        action={async (formData: FormData) => {
          "use server"
          await signIn("credentials", formData)
        }}
      >
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email" className="text-slate-200">Email</Label>
            <Input
              id="email"
              name="email"
              type="email"
              placeholder="name@example.com"
              required
              className="bg-slate-700/50 border-slate-600 text-white placeholder:text-slate-400"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password" className="text-slate-200">Password</Label>
            <Input
              id="password"
              name="password"
              type="password"
              required
              className="bg-slate-700/50 border-slate-600 text-white"
            />
          </div>
          {error && (
            <div className="p-3 rounded-md bg-red-500/10 border border-red-500/50 text-red-400 text-sm">
              {error === "CredentialsSignin" && "Invalid email or password"}
              {error !== "CredentialsSignin" && error !== "" && error !== undefined && error}
            </div>
          )}
        </CardContent>
        <CardFooter className="flex flex-col space-y-4">
          <Button 
            type="submit" 
            className="w-full"
          >
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
