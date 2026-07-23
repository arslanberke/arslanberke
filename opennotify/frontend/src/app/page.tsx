"use client";

import { motion } from "framer-motion";
import { ArrowRight, Bell, Eye, ShieldCheck, Zap } from "lucide-react";
import Link from "next/link";
import { ThemeToggle } from "@/components/theme-toggle";
import { Button } from "@/components/ui/button";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";

const features = [
  {
    icon: Eye,
    title: "Visibility monitoring",
    description:
      "Track when a profile flips between public and private — checked automatically on a schedule.",
  },
  {
    icon: Bell,
    title: "Instant notifications",
    description: "Email, push and in-app alerts the moment a change is detected.",
  },
  {
    icon: Zap,
    title: "Full history",
    description: "A complete timeline of every status change for every profile you follow.",
  },
  {
    icon: ShieldCheck,
    title: "Provider-agnostic",
    description:
      "A modular checker architecture lets you plug in any compliant data provider.",
  },
];

export default function LandingPage() {
  return (
    <div className="mx-auto max-w-6xl px-6">
      <header className="flex items-center justify-between py-6">
        <span className="text-xl font-bold tracking-tight">
          Open<span className="gradient-text">Notify</span>
        </span>
        <nav className="flex items-center gap-2">
          <Link href="/pricing">
            <Button variant="ghost">Pricing</Button>
          </Link>
          <Link href="/login">
            <Button variant="secondary">Sign in</Button>
          </Link>
          <Link href="/register">
            <Button>Get started</Button>
          </Link>
          <ThemeToggle />
        </nav>
      </header>

      <main>
        <section className="py-24 text-center">
          <motion.h1
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="mx-auto max-w-3xl text-5xl font-bold leading-tight tracking-tight md:text-6xl"
          >
            Know the moment a profile goes{" "}
            <span className="gradient-text">public or private</span>
          </motion.h1>
          <motion.p
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="mx-auto mt-6 max-w-xl text-lg text-muted"
          >
            OpenNotify watches profile visibility for you and sends a notification the
            second anything changes. No refreshing, no guessing.
          </motion.p>
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
            className="mt-10 flex justify-center gap-3"
          >
            <Link href="/register">
              <Button size="lg">
                Start monitoring free <ArrowRight className="h-4 w-4" />
              </Button>
            </Link>
            <Link href="/pricing">
              <Button size="lg" variant="secondary">
                View pricing
              </Button>
            </Link>
          </motion.div>
        </section>

        <section className="grid gap-4 pb-24 sm:grid-cols-2 lg:grid-cols-4">
          {features.map((feature, i) => (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.05 }}
            >
              <Card className="h-full">
                <feature.icon className="mb-3 h-6 w-6 text-violet-500" />
                <CardTitle className="text-base">{feature.title}</CardTitle>
                <CardDescription className="mt-1">{feature.description}</CardDescription>
              </Card>
            </motion.div>
          ))}
        </section>
      </main>

      <footer className="border-t border-(--card-border) py-8 text-center text-sm text-muted">
        © {new Date().getFullYear()} OpenNotify
      </footer>
    </div>
  );
}
