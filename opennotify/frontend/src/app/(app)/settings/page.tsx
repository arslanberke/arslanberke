"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTheme } from "next-themes";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { api, tokens } from "@/lib/api";
import { useMe } from "@/lib/hooks";
import { cn } from "@/lib/utils";

function Toggle({
  checked,
  onChange,
  label,
  description,
}: {
  checked: boolean;
  onChange: (value: boolean) => void;
  label: string;
  description?: string;
}) {
  return (
    <div className="flex items-center justify-between gap-4 py-3">
      <div>
        <p className="text-sm font-medium">{label}</p>
        {description && <p className="text-xs text-muted">{description}</p>}
      </div>
      <button
        role="switch"
        aria-checked={checked}
        aria-label={label}
        onClick={() => onChange(!checked)}
        className={cn(
          "relative h-6 w-11 shrink-0 rounded-full transition-colors",
          checked ? "gradient-bg" : "bg-zinc-400/40",
        )}
      >
        <span
          className={cn(
            "absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all",
            checked ? "left-[22px]" : "left-0.5",
          )}
        />
      </button>
    </div>
  );
}

export default function SettingsPage() {
  const router = useRouter();
  const { data: me, isLoading } = useMe();
  const { setTheme, resolvedTheme } = useTheme();
  const queryClient = useQueryClient();
  const [confirmDelete, setConfirmDelete] = useState(false);

  const update = useMutation({
    mutationFn: (body: Record<string, unknown>) =>
      api("/users/me/settings", { method: "PATCH", body }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["me"] }),
    onError: (err) => toast.error(err.message),
  });

  const deleteAccount = useMutation({
    mutationFn: () => api("/users/me", { method: "DELETE" }),
    onSuccess: () => {
      tokens.clear();
      toast.success("Your account has been deleted");
      router.push("/");
    },
    onError: (err) => toast.error(err.message),
  });

  if (isLoading || !me) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Settings</h1>
        <p className="text-sm text-muted">Manage your account and preferences.</p>
      </div>

      <Card>
        <CardTitle className="text-base">Appearance & language</CardTitle>
        <div className="mt-2 divide-y divide-(--card-border)">
          <Toggle
            label="Dark mode"
            description="Switch between light and dark themes"
            checked={resolvedTheme === "dark"}
            onChange={(value) => {
              setTheme(value ? "dark" : "light");
              update.mutate({ darkMode: value });
            }}
          />
          <div className="flex items-center justify-between gap-4 py-3">
            <div>
              <p className="text-sm font-medium">Language</p>
              <p className="text-xs text-muted">Interface language</p>
            </div>
            <select
              aria-label="Language"
              className="glass rounded-xl px-3 py-2 text-sm"
              value={me.language}
              onChange={(e) => update.mutate({ language: e.target.value })}
            >
              <option value="en">English</option>
              <option value="tr">Türkçe</option>
            </select>
          </div>
        </div>
      </Card>

      <Card>
        <CardTitle className="text-base">Notification preferences</CardTitle>
        <div className="mt-2 divide-y divide-(--card-border)">
          <Toggle
            label="Email notifications"
            description="Receive status change alerts by email"
            checked={me.emailNotifications}
            onChange={(value) => update.mutate({ emailNotifications: value })}
          />
          <Toggle
            label="Push notifications"
            description="Receive alerts on your registered devices"
            checked={me.pushNotifications}
            onChange={(value) => update.mutate({ pushNotifications: value })}
          />
          <Toggle
            label="In-app notifications"
            description="Show alerts in the notification center"
            checked={me.inAppNotifications}
            onChange={(value) => update.mutate({ inAppNotifications: value })}
          />
        </div>
      </Card>

      <Card className="border-red-500/30">
        <CardTitle className="text-base text-red-500">Danger zone</CardTitle>
        <CardDescription className="mt-1">
          Deleting your account removes all monitored profiles, history and notifications.
          This cannot be undone.
        </CardDescription>
        <div className="mt-4 flex gap-2">
          {confirmDelete ? (
            <>
              <Button
                variant="destructive"
                onClick={() => deleteAccount.mutate()}
                loading={deleteAccount.isPending}
              >
                Yes, permanently delete
              </Button>
              <Button variant="secondary" onClick={() => setConfirmDelete(false)}>
                Cancel
              </Button>
            </>
          ) : (
            <Button variant="destructive" onClick={() => setConfirmDelete(true)}>
              Delete account
            </Button>
          )}
        </div>
      </Card>
    </div>
  );
}
