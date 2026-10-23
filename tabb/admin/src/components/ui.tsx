import { useEffect, useState, type ReactNode } from "react";
import { formatDate } from "@/lib/format";

export function PageHeader({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children?: ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-3 mb-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-50">{title}</h1>
        {subtitle && <p className="text-sm text-zinc-400 mt-1">{subtitle}</p>}
      </div>
      {children && <div className="flex items-center gap-2">{children}</div>}
    </div>
  );
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={`rounded-xl border border-zinc-800 bg-zinc-900/60 shadow-sm shadow-black/20 ${className}`}
    >
      {children}
    </div>
  );
}

const badgeTones: Record<string, string> = {
  green: "bg-lime-400/10 text-lime-300 ring-lime-400/20",
  red: "bg-rose-400/10 text-rose-300 ring-rose-400/20",
  amber: "bg-amber-400/10 text-amber-300 ring-amber-400/20",
  blue: "bg-sky-400/10 text-sky-300 ring-sky-400/20",
  violet: "bg-violet-400/10 text-violet-300 ring-violet-400/20",
  gray: "bg-zinc-400/10 text-zinc-300 ring-zinc-400/20",
  lime: "bg-lime-400/10 text-lime-300 ring-lime-400/20",
};

export function Badge({
  tone = "gray",
  children,
}: {
  tone?: keyof typeof badgeTones | string;
  children: ReactNode;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium ring-1 ring-inset ${
        badgeTones[tone] ?? badgeTones.gray
      }`}
    >
      {children}
    </span>
  );
}

export function Spinner({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <div className="flex items-center justify-center py-12">
      <div
        className={`animate-spin rounded-full border-2 border-zinc-700 border-t-lime-300 ${className}`}
      />
    </div>
  );
}

export function EmptyState({ message }: { message: string }) {
  return (
    <div className="py-14 text-center text-sm text-zinc-500">
      <p>{message}</p>
    </div>
  );
}

export function ErrorNote({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-rose-400/20 bg-rose-400/10 px-4 py-3 text-sm text-rose-200">
      <span>{message}</span>
      {onRetry && (
        <button onClick={onRetry} className="text-rose-300 underline underline-offset-2">
          Retry
        </button>
      )}
    </div>
  );
}

export function TableWrap({ children }: { children: ReactNode }) {
  return (
    <Card className="overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-sm">{children}</table>
      </div>
    </Card>
  );
}

export function Th({
  children,
  className = "",
}: {
  children?: ReactNode;
  className?: string;
}) {
  return (
    <th
      scope="col"
      className={`border-b border-zinc-800 px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-400 ${className}`}
    >
      {children}
    </th>
  );
}

export function Td({
  children,
  className = "",
}: {
  children?: ReactNode;
  className?: string;
}) {
  return <td className={`px-4 py-3 text-zinc-200 ${className}`}>{children}</td>;
}

export function Tr({ children }: { children: ReactNode }) {
  return <tr className="border-b border-zinc-800/50 last:border-0 hover:bg-zinc-800/30">{children}</tr>;
}

export function DateCell({ date }: { date: string | null | undefined }) {
  return <span className="whitespace-nowrap text-zinc-400">{formatDate(date)}</span>;
}

export function Expand({ open, children }: { open: boolean; children: ReactNode }) {
  if (!open) return null;
  return <tr className="bg-zinc-900/80 border-b border-zinc-800/50">{children}</tr>;
}

export function ConfirmDialog({
  open,
  title,
  body,
  confirmLabel = "Confirm",
  danger = false,
  withReason = true,
  requireReason = false,
  onCancel,
  onConfirm,
}: {
  open: boolean;
  title: string;
  body: string;
  confirmLabel?: string;
  danger?: boolean;
  withReason?: boolean;
  requireReason?: boolean;
  onCancel: () => void;
  onConfirm: (reason: string) => Promise<void> | void;
}) {
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const localOpen = open;
  useEffect(() => {
    if (localOpen) {
      setReason("");
      setError(null);
      setBusy(false);
    }
  }, [localOpen]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!open) return null;

  const run = async () => {
    if (requireReason && reason.trim().length < 3) {
      setError("A reason of at least 3 characters is required.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await onConfirm(reason.trim());
      onCancel();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Action failed");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={busy ? undefined : onCancel} />
      <div className="relative z-10 w-full max-w-md rounded-xl border border-zinc-700 bg-zinc-900 p-6 shadow-2xl">
        <h3 className="text-lg font-semibold text-zinc-100">{title}</h3>
        <p className="mt-2 whitespace-pre-line text-sm text-zinc-400">{body}</p>
        {withReason && (
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder={requireReason ? "Reason (required)" : "Reason (optional)"}
            rows={2}
            disabled={busy}
            className="mt-4 w-full rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50 disabled:opacity-60"
          />
        )}
        {error && <p className="mt-2 text-sm text-rose-300">{error}</p>}
        <div className="mt-5 flex justify-end gap-2">
          <button
            onClick={onCancel}
            disabled={busy}
            className="rounded-lg px-3 py-2 text-sm text-zinc-300 hover:bg-zinc-800 disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={() => void run()}
            disabled={busy}
            className={`rounded-lg px-3 py-2 text-sm font-medium disabled:opacity-60 ${
              danger
                ? "bg-rose-500 text-white hover:bg-rose-400"
                : "bg-lime-300 text-zinc-950 hover:bg-lime-200"
            }`}
          >
            {busy ? "Working…" : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
