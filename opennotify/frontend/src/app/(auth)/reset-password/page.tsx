"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { toast } from "sonner";
import { AuthCard } from "@/components/auth-card";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/input";
import { api } from "@/lib/api";

function ResetPasswordForm() {
  const router = useRouter();
  const token = useSearchParams().get("token") ?? "";
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    setLoading(true);
    try {
      await api("/auth/reset-password", {
        method: "POST",
        body: { token, password: form.get("password") },
      });
      toast.success("Password updated — sign in with your new password");
      router.push("/login");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Reset failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <div className="space-y-1.5">
        <Label htmlFor="password">New password</Label>
        <Input
          id="password"
          name="password"
          type="password"
          required
          minLength={8}
          placeholder="At least 8 characters"
        />
      </div>
      <Button type="submit" className="w-full" loading={loading}>
        Update password
      </Button>
    </form>
  );
}

export default function ResetPasswordPage() {
  return (
    <AuthCard title="Choose a new password">
      <Suspense>
        <ResetPasswordForm />
      </Suspense>
    </AuthCard>
  );
}
