"use client"

import { useState } from "react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Mail, Loader2, ArrowLeft, CheckCircle } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

export default function ForgotPasswordPage() {
    const [email, setEmail] = useState("")
    const [isLoading, setIsLoading] = useState(false)
    const [isSubmitted, setIsSubmitted] = useState(false)
    const { toast } = useToast()

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setIsLoading(true)

        try {
            const response = await fetch("/api/auth/forgot-password", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ email }),
            })

            const data = await response.json()

            if (!response.ok) {
                throw new Error(data.error || "Failed to send reset email")
            }

            setIsSubmitted(true)
        } catch (error) {
            toast({
                title: "Error",
                description: error instanceof Error ? error.message : "Failed to send reset email",
                variant: "destructive",
            })
        } finally {
            setIsLoading(false)
        }
    }

    if (isSubmitted) {
        return (
            <Card className="border-slate-700 bg-slate-800/50 backdrop-blur">
                <CardHeader className="space-y-1 text-center">
                    <div className="flex justify-center mb-4">
                        <div className="rounded-full bg-green-500/10 p-3">
                            <CheckCircle className="h-8 w-8 text-green-500" />
                        </div>
                    </div>
                    <CardTitle className="text-2xl text-white">Check Your Email</CardTitle>
                    <CardDescription className="text-slate-400">
                        If an account exists with {email}, you will receive a password reset link.
                    </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4 text-center">
                    <p className="text-sm text-slate-400">
                        The link will expire in 1 hour.
                    </p>
                    <p className="text-sm text-slate-400">
                        Didn&apos;t receive an email? Check your spam folder or try again.
                    </p>
                </CardContent>
                <CardFooter className="flex flex-col space-y-4">
                    <Button
                        variant="outline"
                        className="w-full"
                        onClick={() => setIsSubmitted(false)}
                    >
                        Try another email
                    </Button>
                    <Link href="/login" className="text-sm text-primary hover:underline">
                        <ArrowLeft className="inline h-4 w-4 mr-1" />
                        Back to login
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
                        <Mail className="h-8 w-8 text-primary" />
                    </div>
                </div>
                <CardTitle className="text-2xl text-white">Forgot Password</CardTitle>
                <CardDescription className="text-slate-400">
                    Enter your email and we&apos;ll send you a reset link
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
                </CardContent>
                <CardFooter className="flex flex-col space-y-4">
                    <Button type="submit" className="w-full" disabled={isLoading}>
                        {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                        Send Reset Link
                    </Button>
                    <Link href="/login" className="text-sm text-primary hover:underline">
                        <ArrowLeft className="inline h-4 w-4 mr-1" />
                        Back to login
                    </Link>
                </CardFooter>
            </form>
        </Card>
    )
}
