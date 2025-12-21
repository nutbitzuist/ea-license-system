"use client"

import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from "@/components/ui/alert-dialog"
import { Switch } from "@/components/ui/switch"
import { Search, Loader2, Eye, Check, X, UserPlus, Trash2 } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

interface User {
  id: string
  email: string
  name: string
  role: "USER" | "ADMIN"
  subscriptionTier: "TIER_1" | "TIER_2" | "TIER_3"
  isActive: boolean
  isApproved: boolean
  createdAt: string
  _count: {
    mtAccounts: number
    eaAccess: number
  }
}

export default function AdminUsersPage() {
  const [search, setSearch] = useState("")
  const [approvedFilter, setApprovedFilter] = useState<string>("all")
  const [isAddUserOpen, setIsAddUserOpen] = useState(false)
  const [newUserName, setNewUserName] = useState("")
  const [newUserEmail, setNewUserEmail] = useState("")
  const [newUserTier, setNewUserTier] = useState<string>("TIER_1")
  const [sendWelcomeEmail, setSendWelcomeEmail] = useState(true)
  const router = useRouter()
  const { toast } = useToast()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ["admin-users", search, approvedFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (search) params.set("search", search)
      if (approvedFilter !== "all") params.set("approved", approvedFilter)
      const res = await fetch(`/api/admin/users?${params}`)
      if (!res.ok) throw new Error("Failed to fetch users")
      return res.json()
    },
  })

  const approveMutation = useMutation({
    mutationFn: async ({ id, isApproved }: { id: string; isApproved: boolean }) => {
      const res = await fetch(`/api/admin/users/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ isApproved }),
      })
      if (!res.ok) throw new Error("Failed to update user")
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-users"] })
      toast({ title: "Success", description: "User updated successfully" })
    },
    onError: () => {
      toast({ title: "Error", description: "Failed to update user", variant: "destructive" })
    },
  })

  const createUserMutation = useMutation({
    mutationFn: async (data: { name: string; email: string; subscriptionTier: string; sendWelcomeEmail: boolean }) => {
      const res = await fetch("/api/admin/users/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      })
      const result = await res.json()
      if (!res.ok) throw new Error(result.error || "Failed to create user")
      return result
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ["admin-users"] })
      toast({ title: "Success", description: data.message })
      setIsAddUserOpen(false)
      setNewUserName("")
      setNewUserEmail("")
      setNewUserTier("TIER_1")
      setSendWelcomeEmail(true)
    },
    onError: (error: Error) => {
      toast({ title: "Error", description: error.message, variant: "destructive" })
    },
  })

  const deleteUserMutation = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/admin/users/${id}`, {
        method: "DELETE",
      })
      const result = await res.json()
      if (!res.ok) throw new Error(result.error || "Failed to delete user")
      return result
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ["admin-users"] })
      toast({ title: "User Deleted", description: data.message })
    },
    onError: (error: Error) => {
      toast({ title: "Error", description: error.message, variant: "destructive" })
    },
  })

  const handleCreateUser = (e: React.FormEvent) => {
    e.preventDefault()
    createUserMutation.mutate({
      name: newUserName,
      email: newUserEmail,
      subscriptionTier: newUserTier,
      sendWelcomeEmail,
    })
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Users</h2>
          <p className="text-muted-foreground">
            Manage user accounts and permissions
          </p>
        </div>
        <Dialog open={isAddUserOpen} onOpenChange={setIsAddUserOpen}>
          <DialogTrigger asChild>
            <Button>
              <UserPlus className="mr-2 h-4 w-4" />
              Add User
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Add New User</DialogTitle>
              <DialogDescription>
                Create a new user account. A welcome email with password setup link will be sent.
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleCreateUser}>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Label htmlFor="name">Name</Label>
                  <Input
                    id="name"
                    placeholder="John Doe"
                    value={newUserName}
                    onChange={(e) => setNewUserName(e.target.value)}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="email">Email</Label>
                  <Input
                    id="email"
                    type="email"
                    placeholder="john@example.com"
                    value={newUserEmail}
                    onChange={(e) => setNewUserEmail(e.target.value)}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="tier">Subscription Tier</Label>
                  <Select value={newUserTier} onValueChange={setNewUserTier}>
                    <SelectTrigger id="tier">
                      <SelectValue placeholder="Select tier" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="TIER_1">Beginner (1 account)</SelectItem>
                      <SelectItem value="TIER_2">Trader (5 accounts)</SelectItem>
                      <SelectItem value="TIER_3">Investor (10 accounts)</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex items-center justify-between">
                  <div className="space-y-0.5">
                    <Label htmlFor="sendEmail">Send Welcome Email</Label>
                    <p className="text-sm text-muted-foreground">
                      Email includes password setup link
                    </p>
                  </div>
                  <Switch
                    id="sendEmail"
                    checked={sendWelcomeEmail}
                    onCheckedChange={setSendWelcomeEmail}
                  />
                </div>
              </div>
              <DialogFooter>
                <Button type="button" variant="outline" onClick={() => setIsAddUserOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" disabled={createUserMutation.isPending}>
                  {createUserMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Create User
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>User Management</CardTitle>
          <CardDescription>View and manage all registered users</CardDescription>
        </CardHeader>
        <CardContent>
          {/* Filters */}
          <div className="flex gap-4 mb-6">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search by name or email..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-10"
              />
            </div>
            <Select value={approvedFilter} onValueChange={setApprovedFilter}>
              <SelectTrigger className="w-48">
                <SelectValue placeholder="Filter by status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Users</SelectItem>
                <SelectItem value="true">Approved</SelectItem>
                <SelectItem value="false">Pending</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Table */}
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : data?.users?.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>User</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Tier</TableHead>
                  <TableHead>Accounts</TableHead>
                  <TableHead>EAs</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Joined</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.users.map((user: User) => (
                  <TableRow key={user.id}>
                    <TableCell>
                      <div>
                        <p className="font-medium">{user.name}</p>
                        <p className="text-sm text-muted-foreground">{user.email}</p>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={user.role === "ADMIN" ? "default" : "secondary"}>
                        {user.role}
                      </Badge>
                    </TableCell>
                    <TableCell>{user.subscriptionTier.replace("_", " ")}</TableCell>
                    <TableCell>{user._count.mtAccounts}</TableCell>
                    <TableCell>{user._count.eaAccess}</TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Badge variant={user.isApproved ? "success" : "warning"}>
                          {user.isApproved ? "Approved" : "Pending"}
                        </Badge>
                        {!user.isActive && (
                          <Badge variant="destructive">Inactive</Badge>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      {new Date(user.createdAt).toLocaleDateString()}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        {!user.isApproved && (
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => approveMutation.mutate({ id: user.id, isApproved: true })}
                            title="Approve"
                          >
                            <Check className="h-4 w-4 text-green-500" />
                          </Button>
                        )}
                        {user.isApproved && (
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => approveMutation.mutate({ id: user.id, isApproved: false })}
                            title="Revoke Approval"
                          >
                            <X className="h-4 w-4 text-destructive" />
                          </Button>
                        )}
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => router.push(`/admin/users/${user.id}`)}
                          title="View Details"
                        >
                          <Eye className="h-4 w-4" />
                        </Button>
                        {user.role !== "ADMIN" && (
                          <AlertDialog>
                            <AlertDialogTrigger asChild>
                              <Button
                                variant="ghost"
                                size="icon"
                                title="Delete User"
                              >
                                <Trash2 className="h-4 w-4 text-destructive" />
                              </Button>
                            </AlertDialogTrigger>
                            <AlertDialogContent>
                              <AlertDialogHeader>
                                <AlertDialogTitle>Delete User</AlertDialogTitle>
                                <AlertDialogDescription>
                                  Are you sure you want to delete {user.name} ({user.email})?
                                  This action cannot be undone and will remove all their data.
                                </AlertDialogDescription>
                              </AlertDialogHeader>
                              <AlertDialogFooter>
                                <AlertDialogCancel>Cancel</AlertDialogCancel>
                                <AlertDialogAction
                                  onClick={() => deleteUserMutation.mutate(user.id)}
                                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                                >
                                  Delete
                                </AlertDialogAction>
                              </AlertDialogFooter>
                            </AlertDialogContent>
                          </AlertDialog>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <div className="text-center py-8">
              <p className="text-muted-foreground">No users found</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
