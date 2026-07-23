"use client";

import { motion } from "framer-motion";
import { CheckCircle2, XCircle } from "lucide-react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { AuthCard } from "@/components/auth-card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";

function VerifyEmail() {
  const token = useSearchParams().get("token") ?? "";
  const [state, setState] = useState<"pending" | "success" | "error">("pending");

  useEffect(() => {
    if (!token) {
      setState("error");
      return;
    }
    api("/auth/verify-email", { method: "POST", body: { token } })
      .then(() => setState("success"))
      .catch(() => setState("error"));
  }, [token]);

  if (state === "pending") return <Skeleton className="h-24 w-full" />;

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      className="flex flex-col items-center gap-3 text-center"
    >
      {state === "success" ? (
        <>
          <CheckCircle2 className="h-12 w-12 text-emerald-500" />
          <p className="text-sm text-muted">Your email has been verified.</p>
          <Link href="/dashboard">
            <Button>Go to dashboard</Button>
          </Link>
        </>
      ) : (
        <>
          <XCircle className="h-12 w-12 text-red-500" />
          <p className="text-sm text-muted">This verification link is invalid or expired.</p>
          <Link href="/login">
            <Button variant="secondary">Back to sign in</Button>
          </Link>
        </>
      )}
    </motion.div>
  );
}

export default function VerifyEmailPage() {
  return (
    <AuthCard title="Email verification">
      <Suspense>
        <VerifyEmail />
      </Suspense>
    </AuthCard>
  );
}
