export type ProfileStatus = "PUBLIC" | "PRIVATE" | "UNKNOWN";
export type Plan = "FREE" | "PRO" | "BUSINESS";

export interface MonitoredProfile {
  id: string;
  username: string;
  currentStatus: ProfileStatus;
  monitoringEnabled: boolean;
  lastCheckedAt: string | null;
  lastChangedAt: string | null;
  createdAt: string;
}

export interface StatusChange {
  id: string;
  oldStatus: ProfileStatus;
  newStatus: ProfileStatus;
  createdAt: string;
  profile?: { username: string };
}

export interface AppNotification {
  id: string;
  channel: "IN_APP" | "EMAIL" | "PUSH";
  title: string;
  body: string;
  readAt: string | null;
  createdAt: string;
}

export interface PlanDefinition {
  id: Plan;
  name: string;
  priceMonthlyUsd: number;
  profileLimit: number | null;
  features: string[];
}

export interface Subscription {
  plan: Plan;
  status: string;
  currentPeriodEnd: string | null;
  planDetails?: PlanDefinition;
}

export interface Me {
  id: string;
  email: string;
  name: string;
  role: "USER" | "ADMIN";
  language: string;
  darkMode: boolean;
  emailVerifiedAt: string | null;
  emailNotifications: boolean;
  pushNotifications: boolean;
  inAppNotifications: boolean;
  subscription: Subscription | null;
}

export interface DashboardStats {
  activeProfiles: number;
  changesDetected: number;
  notificationsSent: number;
  subscription: Subscription;
  recentChanges: StatusChange[];
}
