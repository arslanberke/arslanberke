"use client";

import {
  Bell,
  CreditCard,
  LayoutDashboard,
  LogOut,
  Settings,
  ShieldCheck,
  Users,
} from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { ThemeToggle } from "@/components/theme-toggle";
import { Button } from "@/components/ui/button";
import { api, tokens } from "@/lib/api";
import { useMe } from "@/lib/hooks";
import { cn } from "@/lib/utils";

const navItems = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/profiles", label: "Profiles", icon: Users },
  { href: "/notifications", label: "Notifications", icon: Bell },
  { href: "/pricing", label: "Billing", icon: CreditCard },
  { href: "/settings", label: "Settings", icon: Settings },
];

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const { data: me } = useMe();

  useEffect(() => {
    if (!tokens.access) router.replace("/login");
  }, [router]);

  async function logout() {
    const refreshToken = tokens.refresh;
    if (refreshToken) {
      await api("/auth/logout", { method: "POST", body: { refreshToken } }).catch(() => {});
    }
    tokens.clear();
    router.push("/login");
  }

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <aside className="glass sticky top-0 z-20 flex items-center justify-between gap-2 border-b border-(--card-border) px-4 py-3 md:h-screen md:w-60 md:flex-col md:items-stretch md:border-b-0 md:border-r md:py-6">
        <Link href="/dashboard" className="text-lg font-bold tracking-tight md:px-2">
          Open<span className="gradient-text">Notify</span>
        </Link>
        <nav className="flex gap-1 md:mt-8 md:flex-1 md:flex-col">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition-colors",
                pathname.startsWith(item.href)
                  ? "gradient-bg text-white shadow-md shadow-violet-500/20"
                  : "text-muted hover:bg-black/5 hover:text-foreground dark:hover:bg-white/5",
              )}
            >
              <item.icon className="h-4 w-4" />
              <span className="hidden md:inline">{item.label}</span>
            </Link>
          ))}
          {me?.role === "ADMIN" && (
            <Link
              href="/admin"
              className={cn(
                "flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition-colors",
                pathname.startsWith("/admin")
                  ? "gradient-bg text-white shadow-md shadow-violet-500/20"
                  : "text-muted hover:bg-black/5 hover:text-foreground dark:hover:bg-white/5",
              )}
            >
              <ShieldCheck className="h-4 w-4" />
              <span className="hidden md:inline">Admin</span>
            </Link>
          )}
        </nav>
        <div className="flex items-center gap-1 md:flex-col md:items-stretch">
          <div className="hidden px-3 py-2 text-xs text-muted md:block">
            {me?.email}
          </div>
          <div className="flex items-center gap-1">
            <ThemeToggle />
            <Button variant="ghost" size="icon" aria-label="Sign out" onClick={logout}>
              <LogOut className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </aside>
      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-8 md:px-8">{children}</main>
    </div>
  );
}
