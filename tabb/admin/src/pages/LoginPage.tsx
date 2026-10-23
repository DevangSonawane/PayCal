import { useState, type FormEvent, type ReactNode } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { supabase } from "@/lib/supabase";
import { Spinner } from "@/components/ui";

export function LoginPage() {
  const { status, signIn } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [setupOpen, setSetupOpen] = useState(false);
  const [setupError, setSetupError] = useState<string | null>(null);
  const [setupBusy, setSetupBusy] = useState(false);
  const [name, setName] = useState("Tabbb Admin");
  const [code, setCode] = useState("");

  if (status === "loading") return <Spinner className="h-8 w-8" />;
  if (status === "admin") {
    const from = (location.state as { from?: string } | null)?.from ?? "/";
    return <Navigate to={from} replace />;
  }
  if (status === "member") {
    return (
      <Center>
        <Card>
          <h2 className="text-lg font-semibold text-zinc-100">No admin access</h2>
          <p className="mt-2 text-sm text-zinc-400 max-w-sm">
            You are signed in, but this account is not marked as a PayCal admin.
          </p>
          <SignOutButton />
        </Card>
      </Center>
    );
  }

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const message = await signIn(email, password);
    if (message) {
      setError(message);
      setBusy(false);
      return;
    }
    const from = (location.state as { from?: string } | null)?.from ?? "/";
    navigate(from, { replace: true });
  };

  const runSetup = async () => {
    setSetupBusy(true);
    setSetupError(null);
    try {
      let hadSession = false;
      const signUp = await supabase.auth.signUp({
        email: email.trim(),
        password,
        options: { data: { display_name: name.trim() || "PayCal Admin" } },
      });
      if (signUp.error) {
        const attempt = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });
        if (attempt.error) {
          setSetupError(signUp.error.message);
          return;
        }
        hadSession = true;
      } else if (signUp.data.session) {
        hadSession = true;
      }
      if (!hadSession) {
        setSetupError(
          "Account created. Confirm the verification email first, then press “Create admin” again to activate it.",
        );
        return;
      }
      const { error: rpcError } = await supabase.rpc("declare_first_admin", {
        p_bootstrap_code: code.trim(),
      });
      if (rpcError) {
        setSetupError(rpcError.message);
        return;
      }
      window.location.reload();
    } finally {
      setSetupBusy(false);
    }
  };

  return (
    <Center>
      <form
        onSubmit={(e) => void submit(e)}
        className="w-full max-w-sm rounded-xl border border-zinc-800 bg-zinc-900/60 p-8 shadow-xl"
      >
        <div className="mb-6 flex items-center gap-2">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-lime-300 text-sm font-bold text-zinc-950">
            PC
          </div>
          <div>
            <h1 className="text-lg font-semibold leading-none text-zinc-100">PayCal Admin</h1>
            <p className="mt-1 text-xs text-zinc-500">moderation console</p>
          </div>
        </div>
        <label className="block text-sm text-zinc-400">Email</label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50"
          placeholder="admin@example.com"
          autoComplete="email"
        />
        <label className="mt-4 block text-sm text-zinc-400">Password</label>
        <input
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50"
          placeholder="••••••••"
          autoComplete="current-password"
        />
        {error && <p className="mt-3 text-sm text-rose-300">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="mt-5 w-full rounded-lg bg-lime-300 py-2 text-sm font-semibold text-zinc-950 hover:bg-lime-200 disabled:opacity-60"
        >
          {busy ? "Signing in…" : "Sign in"}
        </button>

        <button
          type="button"
          onClick={() => {
            setSetupOpen((v) => !v);
            setSetupError(null);
          }}
          className="mt-4 w-full text-center text-xs text-zinc-500 hover:text-zinc-300"
        >
          {setupOpen ? "Hide first-admin setup" : "First admin setup →"}
        </button>
        {setupOpen && (
          <div className="mt-4 rounded-lg border border-zinc-700 bg-zinc-800/50 p-4">
            <p className="text-xs text-zinc-400">
              Creates the very first admin. Refused once any admin exists — afterwards new
              admins are managed on the server.
            </p>
            <label className="mt-3 block text-sm text-zinc-400">Bootstrap code</label>
            <input
              value={code}
              onChange={(e) => setCode(e.target.value)}
              className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50"
              placeholder="PAYCAL-BOOTSTRAP-…"
            />
            <label className="mt-3 block text-sm text-zinc-400">Email</label>
            <input
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50"
              placeholder="admin@yourdomain.app"
            />
            <label className="mt-3 block text-sm text-zinc-400">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50"
              placeholder="min. 6 characters"
            />
            <label className="mt-3 block text-sm text-zinc-400">Display name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm text-zinc-200 outline-none focus:border-lime-300/50"
            />
            {setupError && <p className="mt-3 text-sm text-rose-300">{setupError}</p>}
            <button
              type="button"
              disabled={setupBusy}
              onClick={() => void runSetup()}
              className="mt-4 w-full rounded-lg border border-lime-300/50 py-2 text-sm font-semibold text-lime-300 hover:bg-lime-300/10 disabled:opacity-60"
            >
              {setupBusy ? "Creating…" : "Create admin"}
            </button>
          </div>
        )}
      </form>
    </Center>
  );
}

function Center({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen items-center justify-center p-4">{children}</div>
  );
}

function Card({ children }: { children: ReactNode }) {
  return <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-8 text-center">{children}</div>;
}

function SignOutButton() {
  const { signOut } = useAuth();
  return (
    <button
      onClick={() => void signOut()}
      className="mt-5 rounded-lg bg-lime-300 px-4 py-2 text-sm font-medium text-zinc-950 hover:bg-lime-200"
    >
      Sign out
    </button>
  );
}
