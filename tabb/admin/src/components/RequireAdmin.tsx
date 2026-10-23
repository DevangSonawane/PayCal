import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { Spinner } from "@/components/ui";

export function RequireAdmin() {
  const { status } = useAuth();
  const location = useLocation();

  if (status === "loading") {
    return <Spinner className="h-8 w-8" />;
  }
  if (status === "anon") {
    return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  }
  if (status !== "admin") {
    return <NotAdmin />;
  }
  return <Outlet />;
}

function NotAdmin() {
  const { signOut } = useAuth();
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="max-w-sm rounded-xl border border-zinc-800 bg-zinc-900/60 p-8 text-center">
        <h2 className="text-lg font-semibold text-zinc-100">No admin access</h2>
        <p className="mt-2 text-sm text-zinc-400">
          You are signed in, but this account is not marked as a PayCal admin.
        </p>
        <button
          onClick={() => void signOut()}
          className="mt-5 rounded-lg bg-lime-300 px-4 py-2 text-sm font-medium text-zinc-950 hover:bg-lime-200"
        >
          Sign out
        </button>
      </div>
    </div>
  );
}
