"use client";

import { motion } from "framer-motion";
import { ArrowLeft, History } from "lucide-react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { StatusBadge } from "@/components/ui/badge";
import { Card, CardDescription } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { useProfile, useProfileHistory } from "@/lib/hooks";
import { formatDate } from "@/lib/utils";

export default function ProfileDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { data: profile, isLoading } = useProfile(id);
  const { data: history, isLoading: historyLoading } = useProfileHistory(id);

  return (
    <div className="space-y-6">
      <Link
        href="/profiles"
        className="inline-flex items-center gap-2 text-sm text-muted hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" /> Back to profiles
      </Link>

      {isLoading || !profile ? (
        <Skeleton className="h-28 w-full" />
      ) : (
        <Card className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-2xl font-bold tracking-tight">@{profile.username}</h1>
            <CardDescription className="mt-1">
              Last checked {formatDate(profile.lastCheckedAt)} · Last changed{" "}
              {formatDate(profile.lastChangedAt)}
            </CardDescription>
          </div>
          <div className="flex items-center gap-2">
            <StatusBadge status={profile.currentStatus} />
            <span className="text-xs text-muted">
              {profile.monitoringEnabled ? "Monitoring on" : "Monitoring paused"}
            </span>
          </div>
        </Card>
      )}

      <section>
        <h2 className="mb-4 text-lg font-semibold">Status history</h2>
        {historyLoading ? (
          <div className="space-y-3">
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-14 w-full" />
            ))}
          </div>
        ) : !history || history.length === 0 ? (
          <EmptyState
            icon={History}
            title="No changes recorded"
            description="When this profile's visibility changes, every transition will be listed here."
          />
        ) : (
          <div className="relative space-y-0 pl-6 before:absolute before:left-2 before:top-2 before:bottom-2 before:w-px before:bg-(--card-border)">
            {history.map((change, i) => (
              <motion.div
                key={change.id}
                initial={{ opacity: 0, x: -8 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.04 }}
                className="relative pb-6"
              >
                <span className="gradient-bg absolute -left-6 top-1.5 h-3 w-3 rounded-full ring-4 ring-(--background)" />
                <div className="flex flex-wrap items-center gap-2 text-sm">
                  <StatusBadge status={change.oldStatus} />
                  <span className="text-muted">→</span>
                  <StatusBadge status={change.newStatus} />
                </div>
                <p className="mt-1 text-xs text-muted">{formatDate(change.createdAt)}</p>
              </motion.div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
