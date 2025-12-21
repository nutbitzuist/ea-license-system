"use client"

import { useState } from "react"
import { useMutation } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useToast } from "@/hooks/use-toast"
import {
    MessageSquare,
    Send,
    Loader2,
    CheckCircle2,
    Bug,
    Sparkles,
    CreditCard,
    User,
    Wrench,
    HelpCircle,
} from "lucide-react"

const issueTypes = [
    { value: "bug", label: "Bug Report", icon: Bug, description: "Report a problem or error" },
    { value: "feature", label: "Feature Request", icon: Sparkles, description: "Suggest a new feature" },
    { value: "billing", label: "Billing Issue", icon: CreditCard, description: "Questions about payments" },
    { value: "account", label: "Account Issue", icon: User, description: "Login or account problems" },
    { value: "technical", label: "Technical Support", icon: Wrench, description: "EA or trading issues" },
    { value: "other", label: "Other", icon: HelpCircle, description: "General questions" },
]

export default function ContactPage() {
    const { toast } = useToast()
    const [issueType, setIssueType] = useState("")
    const [subject, setSubject] = useState("")
    const [message, setMessage] = useState("")
    const [isSuccess, setIsSuccess] = useState(false)

    const submitMutation = useMutation({
        mutationFn: async (data: { issueType: string; subject: string; message: string }) => {
            const res = await fetch("/api/contact", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(data),
            })
            const result = await res.json()
            if (!res.ok) throw new Error(result.message || "Failed to send message")
            return result
        },
        onSuccess: () => {
            setIsSuccess(true)
            setIssueType("")
            setSubject("")
            setMessage("")
            toast({
                title: "Message Sent!",
                description: "We'll get back to you as soon as possible.",
            })
        },
        onError: (error: Error) => {
            toast({
                title: "Error",
                description: error.message,
                variant: "destructive",
            })
        },
    })

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault()
        if (!issueType || !subject || !message) {
            toast({
                title: "Missing Fields",
                description: "Please fill in all required fields.",
                variant: "destructive",
            })
            return
        }
        submitMutation.mutate({ issueType, subject, message })
    }

    if (isSuccess) {
        return (
            <div className="space-y-6">
                <div>
                    <h2 className="text-3xl font-bold tracking-tight">Contact Us</h2>
                    <p className="text-muted-foreground">Get in touch with our support team</p>
                </div>

                <Card className="max-w-2xl">
                    <CardContent className="flex flex-col items-center justify-center py-16">
                        <CheckCircle2 className="h-16 w-16 text-green-500 mb-4" />
                        <h3 className="text-2xl font-bold mb-2">Message Sent!</h3>
                        <p className="text-muted-foreground text-center mb-6">
                            Thank you for reaching out. We&apos;ll respond to your inquiry as soon as possible.
                        </p>
                        <Button onClick={() => setIsSuccess(false)}>
                            Send Another Message
                        </Button>
                    </CardContent>
                </Card>
            </div>
        )
    }

    return (
        <div className="space-y-6">
            <div>
                <h2 className="text-3xl font-bold tracking-tight">Contact Us</h2>
                <p className="text-muted-foreground">Get in touch with our support team</p>
            </div>

            <div className="grid gap-6 lg:grid-cols-3">
                {/* Contact Form */}
                <Card className="lg:col-span-2">
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <MessageSquare className="h-5 w-5" />
                            Send us a Message
                        </CardTitle>
                        <CardDescription>
                            Fill out the form below and we&apos;ll get back to you shortly.
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={handleSubmit} className="space-y-6">
                            <div className="space-y-2">
                                <Label htmlFor="issueType">Issue Type *</Label>
                                <Select value={issueType} onValueChange={setIssueType}>
                                    <SelectTrigger id="issueType">
                                        <SelectValue placeholder="Select an issue type" />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {issueTypes.map((type) => (
                                            <SelectItem key={type.value} value={type.value}>
                                                <div className="flex items-center gap-2">
                                                    <type.icon className="h-4 w-4" />
                                                    {type.label}
                                                </div>
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="subject">Subject *</Label>
                                <Input
                                    id="subject"
                                    placeholder="Brief description of your issue"
                                    value={subject}
                                    onChange={(e) => setSubject(e.target.value)}
                                    maxLength={100}
                                />
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="message">Message *</Label>
                                <Textarea
                                    id="message"
                                    placeholder="Please provide as much detail as possible..."
                                    className="min-h-[200px]"
                                    value={message}
                                    onChange={(e) => setMessage(e.target.value)}
                                />
                                <p className="text-xs text-muted-foreground">
                                    Minimum 20 characters
                                </p>
                            </div>

                            <Button
                                type="submit"
                                className="w-full"
                                disabled={submitMutation.isPending}
                            >
                                {submitMutation.isPending ? (
                                    <>
                                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                        Sending...
                                    </>
                                ) : (
                                    <>
                                        <Send className="mr-2 h-4 w-4" />
                                        Send Message
                                    </>
                                )}
                            </Button>
                        </form>
                    </CardContent>
                </Card>

                {/* Quick Help */}
                <div className="space-y-4">
                    <Card>
                        <CardHeader>
                            <CardTitle className="text-lg">Quick Help</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            {issueTypes.slice(0, 4).map((type) => (
                                <div
                                    key={type.value}
                                    className="flex items-start gap-3 p-3 rounded-lg bg-muted/50 hover:bg-muted transition-colors cursor-pointer"
                                    onClick={() => setIssueType(type.value)}
                                >
                                    <type.icon className="h-5 w-5 mt-0.5 text-muted-foreground" />
                                    <div>
                                        <div className="font-medium text-sm">{type.label}</div>
                                        <div className="text-xs text-muted-foreground">{type.description}</div>
                                    </div>
                                </div>
                            ))}
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle className="text-lg">Response Time</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <p className="text-sm text-muted-foreground">
                                We typically respond within 24-48 hours during business days.
                                For urgent issues, please indicate so in your subject line.
                            </p>
                        </CardContent>
                    </Card>
                </div>
            </div>
        </div>
    )
}
