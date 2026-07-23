"use client";

import { motion } from "framer-motion";
import { ArrowLeft, Check, Sparkles } from "lucide-react";
import Link from "next/link";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { tokens } from "@/lib/api";
import { usePlans } from "@/lib/hooks";
import { cn } from "@/lib/utils";

export default function PricingPage() {
  const { data: plans, isLoading } = usePlans();
  const loggedIn = typeof window !== "undefined" && !!tokens.access;

  return (
    <div className="mx-auto max-w-5xl px-6 py-12">
      <Link
        href={loggedIn ? "/dashboard" : "/"}
        className="mb-8 inline-flex items-center gap-2 text-sm text-muted hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </Link>
      <div className="mb-12 text-center">
        <h1 className="text-4xl font-bold tracking-tight">
          Simple, <span className="gradient-text">transparent</span> pricing
        </h1>
        <p className="mt-3 text-muted">Start free. Upgrade when you need more profiles.</p>
      </div>

      {isLoading ? (
        <div className="grid gap-6 md:grid-cols-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-96 w-full" />
          ))}
        </div>
      ) : (
        <div className="grid gap-6 md:grid-cols-3">
          {plans?.map((plan, i) => {
            const highlighted = plan.id === "PRO";
            return (
              <motion.div
                key={plan.id}
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.08 }}
              >
                <Card
                  className={cn(
                    "flex h-full flex-col",
                    highlighted && "ring-2 ring-violet-500 shadow-xl shadow-violet-500/10",
                  )}
                >
                  {highlighted && (
                    <span className="mb-3 inline-flex w-fit items-center gap-1 rounded-full bg-violet-500/15 px-3 py-1 text-xs font-medium text-violet-400">
                      <Sparkles className="h-3 w-3" /> Most popular
                    </span>
                  )}
                  <CardTitle>{plan.name}</CardTitle>
                  <div className="mt-2 flex items-baseline gap-1">
                    <span className="text-4xl font-bold">${plan.priceMonthlyUsd}</span>
                    <span className="text-sm text-muted">/month</span>
                  </div>
                  <CardDescription className="mt-1">
                    {plan.profileLimit === null
                      ? "Unlimited monitored profiles"
                      : `Up to ${plan.profileLimit} monitored profiles`}
                  </CardDescription>
                  <ul className="mt-6 flex-1 space-y-2.5">
                    {plan.features.map((feature) => (
                      <li key={feature} className="flex items-start gap-2 text-sm">
                        <Check className="mt-0.5 h-4 w-4 shrink-0 text-emerald-500" />
                        {feature}
                      </li>
                    ))}
                  </ul>
                  <Button
                    className="mt-6 w-full"
                    variant={highlighted ? "default" : "secondary"}
                    onClick={() =>
                      plan.priceMonthlyUsd === 0
                        ? toast.info("You're already on the Free plan")
                        : toast.info("Stripe checkout will be available soon")
                    }
                  >
                    {plan.priceMonthlyUsd === 0 ? "Current plan" : `Upgrade to ${plan.name}`}
                  </Button>
                </Card>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}
