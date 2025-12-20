"use client"

import { useState, useEffect, Suspense } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { KeyRound, Loader2, CheckCircle, XCircle } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

function ResetPasswordForm() {
    const [password, setPassword] = useState("")
    const [confirmPassword, setConfirmPassword] = useState("")
    const [isLoading, setIsLoading] = useState(false)
    const [isSuccess, setIsSuccess] = useState(false)
    const [error, setError] = useState<string | null>(null)
    const router = useRouter()
    const searchParams = useSearchParams()
    const { toast } = useToast()

    const token = searchParams.get("token")

    useEffect(() => {
        if (!token) {
            setError("Missing reset token. Please request a new password reset link.")
        }
    }, [token])

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()

        if (password !== confirmPassword) {
            toast({
                title: "Error",
                description: "Passwords do not match",
                variant: "destructive",
            })
            return
        }

        if (password.length < 8) {
            toast({
                title: "Error",
                description: "Password must be at least 8 characters",
                variant: "destructive",
            })
            return
        }

        setIsLoading(true)

        try {
            const response = await fetch("/api/auth/reset-password", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ token, password }),
            })

            const data = await response.json()

            if (!response.ok) {
                throw new Error(data.error || "Failed to reset password")
            }

            setIsSuccess(true)
            setTimeout(() => {
                router.push("/login")
            }, 3000)
        } catch (error) {
            toast({
                title: "Error",
                description: error instanceof Error ? error.message : "Failed to reset password",
                variant: "destructive",
            })
        } finally {
            setIsLoading(false)
        }
    }

    if (error) {
        return (
            <Card className="border-slate-700 bg-slate-800/50 backdrop-blur">
                <CardHeader className="space-y-1 text-center">
                    <div className="flex justify-center mb-4">
                        <div className="rounded-full bg-red-500/10 p-3">
                            <XCircle className="h-8 w-8 text-red-500" />
                        </div>
                    </div>
                    <CardTitle className="text-2xl text-white">Invalid Link</CardTitle>
                    <CardDescription className="text-slate-400">
                        {error}
                    </CardDescription>
                </CardHeader>
                <CardFooter className="flex justify-center">
                    <Link href="/forgot-password">
                        <Button>Request New Reset Link</Button>
                    </Link>
                </CardFooter>
            </Card>
        )
    }

    if (isSuccess) {
        return (
            <Card className="border-slate-700 bg-slate-800/50 backdrop-blur">
                <CardHeader className="space-y-1 text-center">
                    <div className="flex justify-center mb-4">
                        <div className="rounded-full bg-green-500/10 p-3">
                            <CheckCircle className="h-8 w-8 text-green-500" />
                        </div>
                    </div>
                    <CardTitle className="text-2xl text-white">Password Reset!</CardTitle>
                    <CardDescription className="text-slate-400">
                        Your password has been successfully reset. Redirecting to login...
                    </CardDescription>
                </CardHeader>
                <CardFooter className="flex justify-center">
                    <Link href="/login">
                        <Button>Go to Login</Button>
                    </Link>
                </CardFooter>
            </Card>
        )
    }

    return (
        <Card className="border-slate-700 bg-slate-800/50 backdrop-blur">
            <CardHeader className="space-y-1 text-center">
                <div className="flex justify-center mb-4">
                    <div className="rounded-full bg-primary/10 p-3">
                        <KeyRound className="h-8 w-8 text-primary" />
                    </div>
                </div>
                <CardTitle className="text-2xl text-white">Reset Password</CardTitle>
                <CardDescription className="text-slate-400">
                    Enter your new password
                </CardDescription>
            </CardHeader>
            <form onSubmit={handleSubmit}>
                <CardContent className="space-y-4">
                    <div className="space-y-2">
                        <Label htmlFor="password" className="text-slate-200">New Password</Label>
                        <Input
                            id="password"
                            type="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            required
                            minLength={8}
                            className="bg-slate-700/50 border-slate-600 text-white"
                        />
                    </div>
                    <div className="space-y-2">
                        <Label htmlFor="confirmPassword" className="text-slate-200">Confirm Password</Label>
                        <Input
                            id="confirmPassword"
                            type="password"
                            value={confirmPassword}
                            onChange={(e) => setConfirmPassword(e.target.value)}
                            required
                            className="bg-slate-700/50 border-slate-600 text-white"
                        />
                    </div>
                </CardContent>
                <CardFooter>
                    <Button type="submit" className="w-full" disabled={isLoading}>
                        {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                        Reset Password
                    </Button>
                </CardFooter>
            </form>
        </Card>
    )
}

export default function ResetPasswordPage() {
    return (
        <Suspense fallback={
            <Card className="border-slate-700 bg-slate-800/50 backdrop-blur">
                <CardContent className="flex items-center justify-center py-12">
                    <Loader2 className="h-8 w-8 animate-spin text-primary" />
                </CardContent>
            </Card>
        }>
            <ResetPasswordForm />
        </Suspense>
    )
}
