"use client"

import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Plus, Trash2, Edit, Loader2 } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

interface MtAccount {
  id: string
  accountNumber: string
  brokerName: string
  accountType: "DEMO" | "LIVE"
  terminalType: "MT4" | "MT5"
  nickname: string | null
  isActive: boolean
  lastValidatedAt: string | null
  createdAt: string
}

export default function AccountsPage() {
  const [isAddOpen, setIsAddOpen] = useState(false)
  const [, setEditAccount] = useState<MtAccount | null>(null)
  const [formData, setFormData] = useState({
    accountNumber: "",
    brokerName: "",
    accountType: "DEMO" as "DEMO" | "LIVE",
    terminalType: "MT5" as "MT4" | "MT5",
    nickname: "",
  })
  const { toast } = useToast()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ["accounts"],
    queryFn: async () => {
      const res = await fetch("/api/accounts")
      if (!res.ok) throw new Error("Failed to fetch accounts")
      return res.json()
    },
  })

  const createMutation = useMutation({
    mutationFn: async (data: typeof formData) => {
      const res = await fetch("/api/accounts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      })
      if (!res.ok) {
        const error = await res.json()
        throw new Error(error.error || "Failed to create account")
      }
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["accounts"] })
      setIsAddOpen(false)
      resetForm()
      toast({ title: "Success", description: "Account added successfully" })
    },
    onError: (error: Error) => {
      toast({ title: "Error", description: error.message, variant: "destructive" })
    },
  })

  const updateMutation = useMutation({
    mutationFn: async ({ id, data }: { id: string; data: Partial<MtAccount> }) => {
      const res = await fetch(`/api/accounts/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      })
      if (!res.ok) throw new Error("Failed to update account")
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["accounts"] })
      setEditAccount(null)
      toast({ title: "Success", description: "Account updated successfully" })
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to update account", variant: "destructive" })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/accounts/${id}`, { method: "DELETE" })
      if (!res.ok) throw new Error("Failed to delete account")
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["accounts"] })
      toast({ title: "Success", description: "Account deleted successfully" })
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to delete account", variant: "destructive" })
    },
  })

  const resetForm = () => {
    setFormData({
      accountNumber: "",
      brokerName: "",
      accountType: "DEMO",
      terminalType: "MT5",
      nickname: "",
    })
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    createMutation.mutate(formData)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">MT Accounts</h2>
          <p className="text-muted-foreground">
            Manage your MetaTrader trading accounts
          </p>
        </div>
        <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="mr-2 h-4 w-4" />
              Add Account
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Add MT Account</DialogTitle>
              <DialogDescription>
                Register a new MetaTrader account for license validation
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleSubmit}>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Label htmlFor="accountNumber">Account Number</Label>
                  <Input
                    id="accountNumber"
                    value={formData.accountNumber}
                    onChange={(e) => setFormData({ ...formData, accountNumber: e.target.value })}
                    placeholder="12345678"
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="brokerName">Broker Name</Label>
                  <Input
                    id="brokerName"
                    value={formData.brokerName}
                    onChange={(e) => setFormData({ ...formData, brokerName: e.target.value })}
                    placeholder="ICMarkets"
                    required
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>Account Type</Label>
                    <Select
                      value={formData.accountType}
                      onValueChange={(value: "DEMO" | "LIVE") => setFormData({ ...formData, accountType: value })}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="DEMO">Demo</SelectItem>
                        <SelectItem value="LIVE">Live</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <Label>Terminal Type</Label>
                    <Select
                      value={formData.terminalType}
                      onValueChange={(value: "MT4" | "MT5") => setFormData({ ...formData, terminalType: value })}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="MT4">MT4</SelectItem>
                        <SelectItem value="MT5">MT5</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="nickname">Nickname (Optional)</Label>
                  <Input
                    id="nickname"
                    value={formData.nickname}
                    onChange={(e) => setFormData({ ...formData, nickname: e.target.value })}
                    placeholder="My Trading Account"
                  />
                </div>
              </div>
              <DialogFooter>
                <Button type="button" variant="outline" onClick={() => setIsAddOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" disabled={createMutation.isPending}>
                  {createMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Add Account
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Account Slots Indicator */}
      <Card>
        <CardContent className="py-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium">Account Slots</p>
              <p className="text-2xl font-bold">
                {data?.usedSlots || 0} / {data?.maxAccounts || 1}
              </p>
            </div>
            <div className="h-2 w-48 rounded-full bg-muted">
              <div
                className="h-2 rounded-full bg-primary transition-all"
                style={{
                  width: `${((data?.usedSlots || 0) / (data?.maxAccounts || 1)) * 100}%`,
                }}
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Accounts Table */}
      <Card>
        <CardHeader>
          <CardTitle>Registered Accounts</CardTitle>
          <CardDescription>
            Your MetaTrader accounts registered for license validation
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : data?.accounts?.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Account</TableHead>
                  <TableHead>Broker</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Terminal</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Last Validated</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.accounts.map((account: MtAccount) => (
                  <TableRow key={account.id}>
                    <TableCell>
                      <div>
                        <p className="font-medium">{account.accountNumber}</p>
                        {account.nickname && (
                          <p className="text-sm text-muted-foreground">{account.nickname}</p>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>{account.brokerName}</TableCell>
                    <TableCell>
                      <Badge variant={account.accountType === "LIVE" ? "default" : "secondary"}>
                        {account.accountType}
                      </Badge>
                    </TableCell>
                    <TableCell>{account.terminalType}</TableCell>
                    <TableCell>
                      <Badge variant={account.isActive ? "success" : "destructive"}>
                        {account.isActive ? "Active" : "Inactive"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {account.lastValidatedAt
                        ? new Date(account.lastValidatedAt).toLocaleDateString()
                        : "Never"}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            updateMutation.mutate({
                              id: account.id,
                              data: { isActive: !account.isActive },
                            })
                          }}
                        >
                          <Edit className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => deleteMutation.mutate(account.id)}
                        >
                          <Trash2 className="h-4 w-4 text-destructive" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <div className="text-center py-8">
              <p className="text-muted-foreground">No accounts registered yet</p>
              <Button className="mt-4" onClick={() => setIsAddOpen(true)}>
                <Plus className="mr-2 h-4 w-4" />
                Add Your First Account
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
