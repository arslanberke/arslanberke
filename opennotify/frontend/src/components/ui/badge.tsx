import { cn } from "@/lib/utils";
import type { ProfileStatus } from "@/lib/types";

const statusStyles: Record<ProfileStatus, string> = {
  PUBLIC: "bg-emerald-500/15 text-emerald-500",
  PRIVATE: "bg-amber-500/15 text-amber-500",
  UNKNOWN: "bg-zinc-500/15 text-zinc-400",
};

export function StatusBadge({
  status,
  className,
}: {
  status: ProfileStatus;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium capitalize",
        statusStyles[status],
        className,
      )}
    >
      <span className="h-1.5 w-1.5 rounded-full bg-current" />
      {status.toLowerCase()}
    </span>
  );
}

export function Badge({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full bg-violet-500/15 px-2.5 py-0.5 text-xs font-medium text-violet-400",
        className,
      )}
    >
      {children}
    </span>
  );
}
