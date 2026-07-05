"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Activity, Bell, ScrollText, Users } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardDescription } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import type { ProfileStatus } from "@/lib/types";
import { cn, formatDate } from "@/lib/utils";

interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: string;
  isDisabled: boolean;
  createdAt: string;
  subscription: { plan: string } | null;
  _count: { monitoredProfiles: number };
}

interface AdminProfile {
  id: string;
  username: string;
  currentStatus: ProfileStatus;
  monitoringEnabled: boolean;
  user: { email: string };
}

interface AdminLog {
  id: string;
  action: string;
  createdAt: string;
  user: { email: string } | null;
}

const tabs = ["Users", "Profiles", "Logs"] as const;

export default function AdminPage() {
  const [tab, setTab] = useState<(typeof tabs)[number]>("Users");
  const queryClient = useQueryClient();

  const stats = useQuery({
    queryKey: ["admin", "stats"],
    queryFn: () =>
      api<{ users: number; profiles: number; changes: number; notifications: number }>(
        "/admin/stats",
      ),
  });
  const users = useQuery({
    queryKey: ["admin", "users"],
    queryFn: () => api<AdminUser[]>("/admin/users"),
  });
  const profiles = useQuery({
    queryKey: ["admin", "profiles"],
    queryFn: () => api<AdminProfile[]>("/admin/profiles"),
    enabled: tab === "Profiles",
  });
  const logs = useQuery({
    queryKey: ["admin", "logs"],
    queryFn: () => api<AdminLog[]>("/admin/logs"),
    enabled: tab === "Logs",
  });

  const setDisabled = useMutation({
    mutationFn: ({ id, disabled }: { id: string; disabled: boolean }) =>
      api(`/admin/users/${id}/disabled`, { method: "PATCH", body: { disabled } }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["admin"] }),
    onError: (err) => toast.error(err.message),
  });

  const cards = [
    { label: "Users", value: stats.data?.users, icon: Users },
    { label: "Monitored profiles", value: stats.data?.profiles, icon: Activity },
    { label: "Status changes", value: stats.data?.changes, icon: ScrollText },
    { label: "Notifications", value: stats.data?.notifications, icon: Bell },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Admin panel</h1>
        <p className="text-sm text-muted">Platform-wide overview and management.</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {cards.map((card) => (
          <Card key={card.label} className="flex items-center gap-4 p-5">
            <card.icon className="h-5 w-5 text-violet-500" />
            <div>
              <CardDescription className="text-xs">{card.label}</CardDescription>
              {stats.isLoading ? (
                <Skeleton className="mt-1 h-6 w-12" />
              ) : (
                <p className="text-xl font-semibold">{card.value ?? 0}</p>
              )}
            </div>
          </Card>
        ))}
      </div>

      <div className="glass inline-flex gap-1 rounded-xl p-1">
        {tabs.map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={cn(
              "rounded-lg px-4 py-1.5 text-sm font-medium transition-colors",
              tab === t ? "gradient-bg text-white" : "text-muted hover:text-foreground",
            )}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === "Users" && (
        <Card className="divide-y divide-(--card-border) p-0">
          {users.isLoading && <Skeleton className="m-5 h-32" />}
          {users.data?.map((user) => (
            <div key={user.id} className="flex items-center justify-between gap-4 px-5 py-4">
              <div className="min-w-0">
                <p className="truncate font-medium">
                  {user.name} <span className="text-muted">· {user.email}</span>
                </p>
                <p className="text-xs text-muted">
                  {user._count.monitoredProfiles} profiles · joined {formatDate(user.createdAt)}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <Badge>{user.subscription?.plan ?? "FREE"}</Badge>
                {user.role === "ADMIN" && <Badge>ADMIN</Badge>}
                <Button
                  size="sm"
                  variant={user.isDisabled ? "secondary" : "destructive"}
                  onClick={() =>
                    setDisabled.mutate({ id: user.id, disabled: !user.isDisabled })
                  }
                >
                  {user.isDisabled ? "Enable" : "Disable"}
                </Button>
              </div>
            </div>
          ))}
        </Card>
      )}

      {tab === "Profiles" && (
        <Card className="divide-y divide-(--card-border) p-0">
          {profiles.isLoading && <Skeleton className="m-5 h-32" />}
          {profiles.data?.map((profile) => (
            <div key={profile.id} className="flex items-center justify-between gap-4 px-5 py-4">
              <div className="min-w-0">
                <p className="font-medium">@{profile.username}</p>
                <p className="truncate text-xs text-muted">{profile.user.email}</p>
              </div>
              <div className="flex items-center gap-2">
                <StatusBadge status={profile.currentStatus} />
                {!profile.monitoringEnabled && (
                  <span className="text-xs text-muted">paused</span>
                )}
              </div>
            </div>
          ))}
        </Card>
      )}

      {tab === "Logs" && (
        <Card className="divide-y divide-(--card-border) p-0">
          {logs.isLoading && <Skeleton className="m-5 h-32" />}
          {logs.data?.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-muted">No audit logs yet.</p>
          )}
          {logs.data?.map((log) => (
            <div key={log.id} className="flex items-center justify-between gap-4 px-5 py-3">
              <div>
                <p className="font-mono text-sm">{log.action}</p>
                <p className="text-xs text-muted">{log.user?.email ?? "system"}</p>
              </div>
              <span className="text-xs text-muted">{formatDate(log.createdAt)}</span>
            </div>
          ))}
        </Card>
      )}
    </div>
  );
}
