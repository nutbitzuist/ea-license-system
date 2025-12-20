"use client"

import { useState } from "react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Mail, Loader2 } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

export default function VerifyEmailPage() {
    const [isLoading, setIsLoading] = useState(false)
    const { toast } = useToast()

    const handleResend = async () => {
        setIsLoading(true)

        try {
            const response = await fetch("/api/auth/resend-verification", {
                method: "POST",
            })

            const data = await response.json()

            if (!response.ok) {
                throw new Error(data.error || "Failed to resend verification email")
            }

            toast({
                title: "Email Sent",
                description: "Verification email has been resent. Check your inbox.",
            })
        } catch (error) {
            toast({
                title: "Error",
                description: error instanceof Error ? error.message : "Failed to resend email",
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
                        <Mail className="h-8 w-8 text-primary" />
                    </div>
                </div>
                <CardTitle className="text-2xl text-white">Verify Your Email</CardTitle>
                <CardDescription className="text-slate-400">
                    We&apos;ve sent a verification link to your email address.
                    Please check your inbox and click the link to verify.
                </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4 text-center">
                <p className="text-sm text-slate-400">
                    The verification link will expire in 24 hours.
                </p>
                <p className="text-sm text-slate-400">
                    Didn&apos;t receive the email? Check your spam folder or click below to resend.
                </p>
            </CardContent>
            <CardFooter className="flex flex-col space-y-4">
                <Button
                    onClick={handleResend}
                    disabled={isLoading}
                    className="w-full"
                    variant="outline"
                >
                    {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                    Resend Verification Email
                </Button>
                <Link href="/dashboard" className="text-sm text-primary hover:underline">
                    Continue to Dashboard
                </Link>
            </CardFooter>
        </Card>
    )
}
