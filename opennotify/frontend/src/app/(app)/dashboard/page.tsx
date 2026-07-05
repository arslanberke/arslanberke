"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { Activity, Bell, CreditCard, Plus, Search, Users } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { StatusBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import { useDashboardStats } from "@/lib/hooks";
import { formatDate } from "@/lib/utils";

export default function DashboardPage() {
  const { data, isLoading } = useDashboardStats();
  const queryClient = useQueryClient();
  const [username, setUsername] = useState("");

  const addProfile = useMutation({
    mutationFn: (value: string) =>
      api("/profiles", { method: "POST", body: { username: value } }),
    onSuccess: () => {
      toast.success(`@${username} is now being monitored`);
      setUsername("");
      queryClient.invalidateQueries({ queryKey: ["profiles"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard"] });
    },
    onError: (err) => toast.error(err.message),
  });

  const cards = [
    { label: "Active profiles", value: data?.activeProfiles, icon: Users },
    { label: "Changes detected", value: data?.changesDetected, icon: Activity },
    { label: "Notifications sent", value: data?.notificationsSent, icon: Bell },
    {
      label: "Subscription",
      value: data?.subscription.planDetails?.name ?? data?.subscription.plan,
      icon: CreditCard,
    },
  ];

  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Dashboard</h1>
          <p className="text-sm text-muted">Everything you monitor, at a glance.</p>
        </div>
        <form
          className="flex gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (username.trim()) addProfile.mutate(username.trim());
          }}
        >
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
            <Input
              className="pl-9 sm:w-64"
              placeholder="Add a username…"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
          </div>
          <Button type="submit" loading={addProfile.isPending}>
            <Plus className="h-4 w-4" /> Add
          </Button>
        </form>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {cards.map((card, i) => (
          <motion.div
            key={card.label}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.05 }}
          >
            <Card className="flex items-center gap-4 p-5">
              <div className="gradient-bg flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-white shadow-md shadow-violet-500/20">
                <card.icon className="h-5 w-5" />
              </div>
              <div className="min-w-0">
                <CardDescription className="text-xs">{card.label}</CardDescription>
                {isLoading ? (
                  <Skeleton className="mt-1 h-6 w-16" />
                ) : (
                  <p className="truncate text-xl font-semibold">{card.value ?? 0}</p>
                )}
              </div>
            </Card>
          </motion.div>
        ))}
      </div>

      <section>
        <div className="mb-4 flex items-center justify-between">
          <CardTitle>Recent activity</CardTitle>
          <Link href="/profiles" className="text-sm text-violet-400 hover:underline">
            View all profiles
          </Link>
        </div>
        {isLoading ? (
          <div className="space-y-3">
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-16 w-full" />
            ))}
          </div>
        ) : !data || data.recentChanges.length === 0 ? (
          <EmptyState
            icon={Activity}
            title="No activity yet"
            description="Add a profile above — as soon as a visibility change is detected it will show up here."
          />
        ) : (
          <Card className="divide-y divide-(--card-border) p-0">
            {data.recentChanges.map((change) => (
              <div key={change.id} className="flex items-center justify-between gap-4 px-5 py-4">
                <div className="min-w-0">
                  <p className="truncate font-medium">@{change.profile?.username}</p>
                  <p className="text-xs text-muted">{formatDate(change.createdAt)}</p>
                </div>
                <div className="flex items-center gap-2 text-xs text-muted">
                  <StatusBadge status={change.oldStatus} />
                  <span>→</span>
                  <StatusBadge status={change.newStatus} />
                </div>
              </div>
            ))}
          </Card>
        )}
      </section>
    </div>
  );
}
