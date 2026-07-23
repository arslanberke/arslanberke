"use client";

import { useQuery } from "@tanstack/react-query";
import { api, tokens } from "@/lib/api";
import type {
  AppNotification,
  DashboardStats,
  Me,
  MonitoredProfile,
  PlanDefinition,
  StatusChange,
} from "@/lib/types";

export function useMe() {
  return useQuery({
    queryKey: ["me"],
    queryFn: () => api<Me>("/users/me"),
    enabled: typeof window !== "undefined" && !!tokens.access,
  });
}

export function useDashboardStats() {
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api<DashboardStats>("/dashboard/stats"),
  });
}

export function useProfiles(search?: string) {
  return useQuery({
    queryKey: ["profiles", search ?? ""],
    queryFn: () =>
      api<MonitoredProfile[]>(
        `/profiles${search ? `?search=${encodeURIComponent(search)}` : ""}`,
      ),
  });
}

export function useProfile(id: string) {
  return useQuery({
    queryKey: ["profiles", "detail", id],
    queryFn: () => api<MonitoredProfile>(`/profiles/${id}`),
  });
}

export function useProfileHistory(id: string) {
  return useQuery({
    queryKey: ["profiles", "history", id],
    queryFn: () => api<StatusChange[]>(`/profiles/${id}/history`),
  });
}

export function useNotifications() {
  return useQuery({
    queryKey: ["notifications"],
    queryFn: () => api<AppNotification[]>("/notifications"),
  });
}

export function usePlans() {
  return useQuery({
    queryKey: ["plans"],
    queryFn: () => api<PlanDefinition[]>("/billing/plans"),
  });
}
