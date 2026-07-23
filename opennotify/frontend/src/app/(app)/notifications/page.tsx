"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { Bell, CheckCheck } from "lucide-react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import { useNotifications } from "@/lib/hooks";
import { cn, formatDate } from "@/lib/utils";

export default function NotificationsPage() {
  const { data: notifications, isLoading } = useNotifications();
  const queryClient = useQueryClient();

  const markAllRead = useMutation({
    mutationFn: () => api("/notifications/read-all", { method: "PATCH" }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["notifications"] }),
    onError: (err) => toast.error(err.message),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Notifications</h1>
          <p className="text-sm text-muted">Everything OpenNotify has told you.</p>
        </div>
        <Button
          variant="secondary"
          onClick={() => markAllRead.mutate()}
          loading={markAllRead.isPending}
        >
          <CheckCheck className="h-4 w-4" /> Mark all read
        </Button>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-16 w-full" />
          ))}
        </div>
      ) : !notifications || notifications.length === 0 ? (
        <EmptyState
          icon={Bell}
          title="No notifications"
          description="When a monitored profile changes visibility, you'll see it here."
        />
      ) : (
        <div className="space-y-3">
          {notifications.map((notification, i) => (
            <motion.div
              key={notification.id}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.03 }}
            >
              <Card
                className={cn(
                  "flex items-center justify-between gap-4 p-5",
                  !notification.readAt && "ring-1 ring-violet-500/30",
                )}
              >
                <div className="min-w-0">
                  <p className="font-medium">{notification.title}</p>
                  <p className="truncate text-sm text-muted">{notification.body}</p>
                </div>
                <div className="flex shrink-0 flex-col items-end gap-1">
                  <Badge>{notification.channel.replace("_", "-").toLowerCase()}</Badge>
                  <span className="text-xs text-muted">
                    {formatDate(notification.createdAt)}
                  </span>
                </div>
              </Card>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}
