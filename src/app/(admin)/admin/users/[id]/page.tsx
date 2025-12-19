"use client"

import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useParams, useRouter } from "next/navigation"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Switch } from "@/components/ui/switch"
import { Label } from "@/components/ui/label"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { ArrowLeft, Loader2, Plus, Trash2 } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

export default function UserDetailPage() {
  const params = useParams()
  const router = useRouter()
  const { toast } = useToast()
  const queryClient = useQueryClient()
  const [isGrantEaOpen, setIsGrantEaOpen] = useState(false)
  const [selectedEaId, setSelectedEaId] = useState("")

  const { data, isLoading } = useQuery({
    queryKey: ["admin-user", params.id],
    queryFn: async () => {
      const res = await fetch(`/api/admin/users/${params.id}`)
      if (!res.ok) throw new Error("Failed to fetch user")
      return res.json()
    },
  })

  const { data: allEas } = useQuery({
    queryKey: ["admin-eas-list"],
    queryFn: async () => {
      const res = await fetch("/api/admin/eas")
      if (!res.ok) throw new Error("Failed to fetch EAs")
      return res.json()
    },
  })

  const updateMutation = useMutation({
    mutationFn: async (updates: Record<string, unknown>) => {
      const res = await fetch(`/api/admin/users/${params.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(updates),
      })
      if (!res.ok) throw new Error("Failed to update user")
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-user", params.id] })
      toast({ title: "Success", description: "User updated successfully" })
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to update user", variant: "destructive" })
    },
  })

  const grantEaMutation = useMutation({
    mutationFn: async (eaId: string) => {
      const res = await fetch(`/api/admin/users/${params.id}/grant-ea`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ eaId }),
      })
      if (!res.ok) throw new Error("Failed to grant EA access")
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-user", params.id] })
      setIsGrantEaOpen(false)
      setSelectedEaId("")
      toast({ title: "Success", description: "EA access granted" })
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to grant EA access", variant: "destructive" })
    },
  })

  const revokeEaMutation = useMutation({
    mutationFn: async (eaId: string) => {
      const res = await fetch(`/api/admin/users/${params.id}/revoke-ea/${eaId}`, {
        method: "DELETE",
      })
      if (!res.ok) throw new Error("Failed to revoke EA access")
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-user", params.id] })
      toast({ title: "Success", description: "EA access revoked" })
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to revoke EA access", variant: "destructive" })
    },
  })

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  const user = data?.user
  const availableEas = allEas?.eas?.filter(
    (ea: { id: string }) => !user?.eaAccess?.some((access: { eaId: string }) => access.eaId === ea.id)
  )

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" onClick={() => router.back()}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <h2 className="text-3xl font-bold tracking-tight">{user?.name}</h2>
          <p className="text-muted-foreground">{user?.email}</p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* User Settings */}
        <Card>
          <CardHeader>
            <CardTitle>User Settings</CardTitle>
            <CardDescription>Manage user account settings</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <Label>Approved</Label>
                <p className="text-sm text-muted-foreground">Allow user to use the system</p>
              </div>
              <Switch
                checked={user?.isApproved}
                onCheckedChange={(checked) => updateMutation.mutate({ isApproved: checked })}
              />
            </div>

            <div className="flex items-center justify-between">
              <div>
                <Label>Active</Label>
                <p className="text-sm text-muted-foreground">Enable/disable user account</p>
              </div>
              <Switch
                checked={user?.isActive}
                onCheckedChange={(checked) => updateMutation.mutate({ isActive: checked })}
              />
            </div>

            <div className="space-y-2">
              <Label>Role</Label>
              <Select
                value={user?.role}
                onValueChange={(value) => updateMutation.mutate({ role: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="USER">User</SelectItem>
                  <SelectItem value="ADMIN">Admin</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label>Subscription Tier</Label>
              <Select
                value={user?.subscriptionTier}
                onValueChange={(value) => updateMutation.mutate({ subscriptionTier: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="TIER_1">Tier 1 (1 account)</SelectItem>
                  <SelectItem value="TIER_2">Tier 2 (5 accounts)</SelectItem>
                  <SelectItem value="TIER_3">Tier 3 (10 accounts)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </CardContent>
        </Card>

        {/* Account Info */}
        <Card>
          <CardHeader>
            <CardTitle>Account Information</CardTitle>
            <CardDescription>User account details</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label className="text-muted-foreground">Created</Label>
                <p className="font-medium">
                  {new Date(user?.createdAt).toLocaleDateString()}
                </p>
              </div>
              <div>
                <Label className="text-muted-foreground">MT Accounts</Label>
                <p className="font-medium">{user?.mtAccounts?.length || 0}</p>
              </div>
              <div>
                <Label className="text-muted-foreground">EA Access</Label>
                <p className="font-medium">{user?.eaAccess?.length || 0}</p>
              </div>
              <div>
                <Label className="text-muted-foreground">Status</Label>
                <div className="flex gap-2 mt-1">
                  <Badge variant={user?.isApproved ? "success" : "warning"}>
                    {user?.isApproved ? "Approved" : "Pending"}
                  </Badge>
                  {!user?.isActive && <Badge variant="destructive">Inactive</Badge>}
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* MT Accounts */}
      <Card>
        <CardHeader>
          <CardTitle>MT Accounts</CardTitle>
          <CardDescription>User&apos;s registered MetaTrader accounts</CardDescription>
        </CardHeader>
        <CardContent>
          {user?.mtAccounts?.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Account</TableHead>
                  <TableHead>Broker</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Terminal</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {user.mtAccounts.map((account: {
                  id: string
                  accountNumber: string
                  brokerName: string
                  accountType: string
                  terminalType: string
                  isActive: boolean
                }) => (
                  <TableRow key={account.id}>
                    <TableCell className="font-medium">{account.accountNumber}</TableCell>
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
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <p className="text-muted-foreground text-center py-4">No accounts registered</p>
          )}
        </CardContent>
      </Card>

      {/* EA Access */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle>EA Access</CardTitle>
            <CardDescription>Expert Advisors this user can access</CardDescription>
          </div>
          <Dialog open={isGrantEaOpen} onOpenChange={setIsGrantEaOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="mr-2 h-4 w-4" />
                Grant Access
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Grant EA Access</DialogTitle>
                <DialogDescription>
                  Select an Expert Advisor to grant access to this user
                </DialogDescription>
              </DialogHeader>
              <div className="py-4">
                <Select value={selectedEaId} onValueChange={setSelectedEaId}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select an EA" />
                  </SelectTrigger>
                  <SelectContent>
                    {availableEas?.map((ea: { id: string; name: string; eaCode: string }) => (
                      <SelectItem key={ea.id} value={ea.id}>
                        {ea.name} ({ea.eaCode})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setIsGrantEaOpen(false)}>
                  Cancel
                </Button>
                <Button
                  onClick={() => grantEaMutation.mutate(selectedEaId)}
                  disabled={!selectedEaId || grantEaMutation.isPending}
                >
                  {grantEaMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Grant Access
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </CardHeader>
        <CardContent>
          {user?.eaAccess?.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>EA Name</TableHead>
                  <TableHead>Code</TableHead>
                  <TableHead>Granted</TableHead>
                  <TableHead>Expires</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {user.eaAccess.map((access: {
                  id: string
                  eaId: string
                  grantedAt: string
                  expiresAt: string | null
                  ea: { name: string; eaCode: string }
                }) => (
                  <TableRow key={access.id}>
                    <TableCell className="font-medium">{access.ea.name}</TableCell>
                    <TableCell>{access.ea.eaCode}</TableCell>
                    <TableCell>{new Date(access.grantedAt).toLocaleDateString()}</TableCell>
                    <TableCell>
                      {access.expiresAt
                        ? new Date(access.expiresAt).toLocaleDateString()
                        : "Never"}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => revokeEaMutation.mutate(access.eaId)}
                      >
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <p className="text-muted-foreground text-center py-4">No EA access granted</p>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
