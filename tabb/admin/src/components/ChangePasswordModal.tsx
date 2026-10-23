import { useEffect, useState } from "react";
import { KeyRound, X } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/lib/auth";

export function ChangePasswordModal({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const { userId } = useAuth();
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  useEffect(() => {
    if (open) {
      setCurrent("");
      setNext("");
      setConfirm("");
      setBusy(false);
      setError(null);
      setDone(false);
    }
  }, [open]);

  const submit = async () => {
    if (!userId) {
      setError("Not signed in.");
      return;
    }
    if (next.length < 8) {
      setError("New password must be at least 8 characters.");
      return;
    }
    if (next !== confirm) {
      setError("New passwords don't match.");
      return;
    }
    setBusy(true);
    setError(null);

    const { data: sessionData } = await supabase.auth.getSession();
    const email = sessionData.session?.user?.email;
    if (!email) {
      setError("Session expired — sign in again.");
      setBusy(false);
      return;
    }
    const check = await supabase.auth.signInWithPassword({ email, password: current });
    if (check.error) {
      setError("Current password is incorrect.");
      setBusy(false);
      return;
    }

    const { error: updateError } = await supabase.auth.updateUser({ password: next });
    if (updateError) {
      setError(updateError.message);
      setBusy(false);
      return;
    }
    setDone(true);
    setBusy(false);
  };

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={busy ? undefined : onClose} />
      <div className="relative z-10 w-full max-w-md rounded-xl border border-zinc-700 bg-zinc-900 p-6 shadow-2xl">
        <button
          onClick={onClose}
          disabled={busy}
          className="absolute right-3 top-3 text-zinc-500 hover:text-zinc-300 disabled:opacity-40"
          aria-label="Close"
        >
          <X className="h-4 w-4" />
        </button>
        <div className="flex items-center gap-2">
          <KeyRound className="h-5 w-5 text-lime-300" />
          <h3 className="text-lg font-semibold text-zinc-100">Change password</h3>
        </div>

        {done ? (
          <>
            <p className="mt-4 text-sm text-lime-300">Password changed successfully.</p>
            <div className="mt-5 flex justify-end">
              <button
                onClick={onClose}
                className="rounded-lg bg-lime-300 px-3 py-2 text-sm font-medium text-zinc-950 hover:bg-lime-200"
              >
                Done
              </button>
            </div>
          </>
        ) : (
          <>
            <Field label="Current password" value={current} onChange={setCurrent} autoComplete="current-password" busy={busy} />
            <Field label="New password (min. 8 characters)" value={next} onChange={setNext} autoComplete="new-password" busy={busy} />
            <Field label="Confirm new password" value={confirm} onChange={setConfirm} autoComplete="new-password" busy={busy} />
            {error && <p className="mt-3 text-sm text-rose-300">{error}</p>}
            <div className="mt-5 flex justify-end gap-2">
              <button
                onClick={onClose}
                disabled={busy}
                className="rounded-lg px-3 py-2 text-sm text-zinc-300 hover:bg-zinc-800 disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={() => void submit()}
                disabled={busy}
                className="rounded-lg bg-lime-300 px-3 py-2 text-sm font-medium text-zinc-950 hover:bg-lime-200 disabled:opacity-60"
              >
                {busy ? "Updating…" : "Change password"}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  autoComplete,
  busy,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  autoComplete: string;
  busy: boolean;
}) {
  return (
    <div className="mt-4">
      <label className="block text-sm text-zinc-400">{label}</label>
      <input
        type="password"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        autoComplete={autoComplete}
        disabled={busy}
        className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50 disabled:opacity-60"
      />
    </div>
  );
}
