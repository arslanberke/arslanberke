"use client";

import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { AuthCard } from "@/components/auth-card";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/input";
import { api } from "@/lib/api";

export default function ForgotPasswordPage() {
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    setLoading(true);
    try {
      await api("/auth/forgot-password", {
        method: "POST",
        body: { email: form.get("email") },
      });
      setSent(true);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthCard
      title="Reset your password"
      subtitle="We'll email you a link to set a new password"
    >
      {sent ? (
        <p className="text-sm text-muted">
          If an account exists for that email, a reset link is on its way.
        </p>
      ) : (
        <form onSubmit={onSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="email">Email</Label>
            <Input id="email" name="email" type="email" required placeholder="you@example.com" />
          </div>
          <Button type="submit" className="w-full" loading={loading}>
            Send reset link
          </Button>
        </form>
      )}
      <p className="mt-6 text-center text-sm text-muted">
        <Link href="/login" className="text-violet-400 hover:underline">
          Back to sign in
        </Link>
      </p>
    </AuthCard>
  );
}
