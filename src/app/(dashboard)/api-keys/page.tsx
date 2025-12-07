"use client"

import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Copy, RefreshCw, Eye, EyeOff, Loader2, AlertTriangle } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"

export default function ApiKeysPage() {
  const [showApiKey, setShowApiKey] = useState(false)
  const [showApiSecret, setShowApiSecret] = useState(false)
  const [isRegenerateOpen, setIsRegenerateOpen] = useState(false)
  const { toast } = useToast()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ["api-credentials"],
    queryFn: async () => {
      const res = await fetch("/api/credentials")
      if (!res.ok) throw new Error("Failed to fetch credentials")
      return res.json()
    },
  })

  const regenerateMutation = useMutation({
    mutationFn: async () => {
      const res = await fetch("/api/credentials/regenerate", { method: "POST" })
      if (!res.ok) throw new Error("Failed to regenerate credentials")
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["api-credentials"] })
      setIsRegenerateOpen(false)
      toast({ title: "Success", description: "API credentials regenerated successfully" })
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to regenerate credentials", variant: "destructive" })
    },
  })

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text)
    toast({ title: "Copied", description: `${label} copied to clipboard` })
  }

  const maskValue = (value: string) => {
    if (!value) return ""
    return value.slice(0, 8) + "•".repeat(16) + value.slice(-4)
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">API Keys</h2>
        <p className="text-muted-foreground">
          Manage your API credentials for EA license validation
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>API Credentials</CardTitle>
          <CardDescription>
            Use these credentials in your Expert Advisors to validate licenses
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : (
            <>
              <div className="space-y-2">
                <Label>API Key</Label>
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <Input
                      value={showApiKey ? data?.apiKey : maskValue(data?.apiKey || "")}
                      readOnly
                      className="pr-20 font-mono"
                    />
                    <Button
                      variant="ghost"
                      size="icon"
                      className="absolute right-10 top-0 h-full"
                      onClick={() => setShowApiKey(!showApiKey)}
                    >
                      {showApiKey ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="absolute right-0 top-0 h-full"
                      onClick={() => copyToClipboard(data?.apiKey, "API Key")}
                    >
                      <Copy className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </div>

              <div className="space-y-2">
                <Label>API Secret</Label>
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <Input
                      value={showApiSecret ? data?.apiSecret : maskValue(data?.apiSecret || "")}
                      readOnly
                      className="pr-20 font-mono"
                    />
                    <Button
                      variant="ghost"
                      size="icon"
                      className="absolute right-10 top-0 h-full"
                      onClick={() => setShowApiSecret(!showApiSecret)}
                    >
                      {showApiSecret ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="absolute right-0 top-0 h-full"
                      onClick={() => copyToClipboard(data?.apiSecret, "API Secret")}
                    >
                      <Copy className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </div>

              <div className="pt-4 border-t">
                <Dialog open={isRegenerateOpen} onOpenChange={setIsRegenerateOpen}>
                  <DialogTrigger asChild>
                    <Button variant="outline">
                      <RefreshCw className="mr-2 h-4 w-4" />
                      Regenerate Credentials
                    </Button>
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle className="flex items-center gap-2">
                        <AlertTriangle className="h-5 w-5 text-destructive" />
                        Regenerate API Credentials
                      </DialogTitle>
                      <DialogDescription>
                        This will invalidate your current API credentials. All Expert Advisors
                        using the old credentials will stop working until updated with the new ones.
                      </DialogDescription>
                    </DialogHeader>
                    <DialogFooter>
                      <Button variant="outline" onClick={() => setIsRegenerateOpen(false)}>
                        Cancel
                      </Button>
                      <Button
                        variant="destructive"
                        onClick={() => regenerateMutation.mutate()}
                        disabled={regenerateMutation.isPending}
                      >
                        {regenerateMutation.isPending && (
                          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        )}
                        Regenerate
                      </Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Usage Instructions</CardTitle>
          <CardDescription>
            How to use your API credentials in Expert Advisors
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="rounded-lg bg-muted p-4">
            <pre className="text-sm overflow-x-auto">
{`// In your EA input parameters
input string InpApiKey = "";      // API Key
input string InpApiSecret = "";   // API Secret

// Initialize license validator
CLicenseValidator *validator = new CLicenseValidator(
    InpApiKey,
    InpApiSecret,
    "your_ea_code",
    "1.0.0"
);`}
            </pre>
          </div>
          <p className="text-sm text-muted-foreground">
            Copy your API Key and API Secret into the EA input parameters when attaching
            the EA to a chart. The EA will automatically validate the license on startup
            and periodically during operation.
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
