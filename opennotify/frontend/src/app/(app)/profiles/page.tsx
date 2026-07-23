"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { Pause, Play, Plus, Search, Trash2, Users } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { StatusBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import { useProfiles } from "@/lib/hooks";
import { formatDate } from "@/lib/utils";

export default function ProfilesPage() {
  const [search, setSearch] = useState("");
  const [username, setUsername] = useState("");
  const { data: profiles, isLoading } = useProfiles(search || undefined);
  const queryClient = useQueryClient();

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["profiles"] });
    queryClient.invalidateQueries({ queryKey: ["dashboard"] });
  };

  const addProfile = useMutation({
    mutationFn: (value: string) =>
      api("/profiles", { method: "POST", body: { username: value } }),
    onSuccess: () => {
      toast.success(`@${username} is now being monitored`);
      setUsername("");
      invalidate();
    },
    onError: (err) => toast.error(err.message),
  });

  const toggle = useMutation({
    mutationFn: ({ id, enabled }: { id: string; enabled: boolean }) =>
      api(`/profiles/${id}/${enabled ? "pause" : "resume"}`, { method: "PATCH" }),
    onSuccess: invalidate,
    onError: (err) => toast.error(err.message),
  });

  const remove = useMutation({
    mutationFn: (id: string) => api(`/profiles/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      toast.success("Profile removed");
      invalidate();
    },
    onError: (err) => toast.error(err.message),
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Monitored profiles</h1>
          <p className="text-sm text-muted">Add, pause or remove the usernames you follow.</p>
        </div>
        <form
          className="flex gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (username.trim()) addProfile.mutate(username.trim());
          }}
        >
          <Input
            className="sm:w-56"
            placeholder="@username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
          <Button type="submit" loading={addProfile.isPending}>
            <Plus className="h-4 w-4" /> Add
          </Button>
        </form>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
        <Input
          className="pl-9"
          placeholder="Search profiles…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-20 w-full" />
          ))}
        </div>
      ) : !profiles || profiles.length === 0 ? (
        <EmptyState
          icon={Users}
          title={search ? "No matches" : "Nothing monitored yet"}
          description={
            search
              ? "No monitored profiles match your search."
              : "Add an Instagram username above and OpenNotify will start watching its visibility."
          }
        />
      ) : (
        <div className="space-y-3">
          {profiles.map((profile, i) => (
            <motion.div
              key={profile.id}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.03 }}
            >
              <Card className="flex flex-col gap-3 p-5 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <Link
                    href={`/profiles/${profile.id}`}
                    className="font-semibold hover:underline"
                  >
                    @{profile.username}
                  </Link>
                  <p className="text-xs text-muted">
                    Checked {formatDate(profile.lastCheckedAt)} · Changed{" "}
                    {formatDate(profile.lastChangedAt)}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <StatusBadge status={profile.currentStatus} />
                  {!profile.monitoringEnabled && (
                    <span className="rounded-full bg-zinc-500/15 px-2.5 py-0.5 text-xs text-zinc-400">
                      Paused
                    </span>
                  )}
                  <Button
                    variant="secondary"
                    size="icon"
                    aria-label={profile.monitoringEnabled ? "Pause" : "Resume"}
                    onClick={() =>
                      toggle.mutate({ id: profile.id, enabled: profile.monitoringEnabled })
                    }
                  >
                    {profile.monitoringEnabled ? (
                      <Pause className="h-4 w-4" />
                    ) : (
                      <Play className="h-4 w-4" />
                    )}
                  </Button>
                  <Button
                    variant="destructive"
                    size="icon"
                    aria-label="Remove"
                    onClick={() => remove.mutate(profile.id)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </Card>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}
