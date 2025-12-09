"use client"

import { useQuery } from "@tanstack/react-query"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Download, Bot, Loader2 } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

interface ExpertAdvisor {
  id: string
  eaCode: string
  name: string
  description: string | null
  currentVersion: string
  mt4FileName: string | null
  mt5FileName: string | null
  isActive: boolean
  expiresAt: string | null
}

export default function EAsPage() {
  const { toast } = useToast()

  const { data, isLoading } = useQuery({
    queryKey: ["user-eas"],
    queryFn: async () => {
      const res = await fetch("/api/eas")
      if (!res.ok) throw new Error("Failed to fetch EAs")
      return res.json()
    },
  })

  const handleDownload = async (eaCode: string, terminal: "MT4" | "MT5") => {
    try {
      const res = await fetch(`/api/eas/${eaCode}/download?terminal=${terminal}`)
      if (!res.ok) {
        const error = await res.json()
        throw new Error(error.error || "Download failed")
      }
      
      const blob = await res.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement("a")
      a.href = url
      a.download = `${eaCode}_${terminal}.ex${terminal === "MT4" ? "4" : "5"}`
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
      
      toast({ title: "Success", description: "Download started" })
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Download failed",
        variant: "destructive",
      })
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Expert Advisors</h2>
        <p className="text-muted-foreground">
          Download and manage your licensed Expert Advisors
        </p>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      ) : data?.eas?.length > 0 ? (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {data.eas.map((ea: ExpertAdvisor) => (
            <Card key={ea.id}>
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="rounded-lg bg-primary/10 p-2">
                      <Bot className="h-6 w-6 text-primary" />
                    </div>
                    <div>
                      <CardTitle className="text-lg">{ea.name}</CardTitle>
                      <CardDescription>{ea.eaCode}</CardDescription>
                    </div>
                  </div>
                  <Badge variant="secondary">v{ea.currentVersion}</Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                {ea.description && (
                  <p className="text-sm text-muted-foreground">{ea.description}</p>
                )}
                
                {ea.expiresAt && (
                  <div className="text-sm">
                    <span className="text-muted-foreground">Expires: </span>
                    <span className={new Date(ea.expiresAt) < new Date() ? "text-destructive" : ""}>
                      {new Date(ea.expiresAt).toLocaleDateString()}
                    </span>
                  </div>
                )}

                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    className="flex-1"
                    onClick={() => handleDownload(ea.eaCode, "MT4")}
                  >
                    <Download className="mr-2 h-4 w-4" />
                    MT4
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    className="flex-1"
                    onClick={() => handleDownload(ea.eaCode, "MT5")}
                  >
                    <Download className="mr-2 h-4 w-4" />
                    MT5
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <Bot className="h-12 w-12 text-muted-foreground mb-4" />
            <h3 className="text-lg font-semibold">No Expert Advisors</h3>
            <p className="text-muted-foreground text-center mt-2">
              You don&apos;t have access to any Expert Advisors yet.
              <br />
              Contact an administrator to get access.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  )
}
