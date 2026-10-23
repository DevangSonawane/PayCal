import { useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import {
  Activity,
  ArrowLeftRight,
  Boxes,
  Flag,
  KeyRound,
  LayoutDashboard,
  LogOut,
  ReceiptText,
  Repeat,
  ScrollText,
  Users,
} from "lucide-react";
import { useAuth } from "@/lib/auth";
import { ChangePasswordModal } from "@/components/ChangePasswordModal";

const nav: { to: string; label: string; icon: typeof LayoutDashboard; end?: boolean }[] = [
  { to: "/", label: "Overview", icon: LayoutDashboard, end: true },
  { to: "/users", label: "Users", icon: Users },
  { to: "/cribs", label: "Cribs", icon: Boxes },
  { to: "/expenses", label: "Expenses", icon: ReceiptText },
  { to: "/disputes", label: "Disputes", icon: Flag },
  { to: "/settlements", label: "Settlements", icon: ArrowLeftRight },
  { to: "/recurring", label: "Schedules", icon: Repeat },
  { to: "/activity", label: "Activity", icon: Activity },
  { to: "/audit", label: "Admin audit log", icon: ScrollText },
];

export function AppShell() {
  const { displayName, signOut } = useAuth();
  const navigate = useNavigate();
  const [pwOpen, setPwOpen] = useState(false);

  return (
    <div className="flex min-h-screen">
      <aside className="fixed inset-y-0 left-0 z-40 flex w-60 flex-col border-r border-zinc-800 bg-zinc-900/80">
        <div className="flex items-center gap-2 px-5 py-5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-lime-300 text-sm font-bold text-zinc-950">
            PC
          </div>
          <div>
            <p className="text-sm font-semibold text-zinc-100 leading-none">PayCal Admin</p>
            <p className="text-xs text-zinc-500 mt-0.5">moderation console</p>
          </div>
        </div>
        <nav className="flex-1 space-y-1 overflow-y-auto px-3 pb-4">
          {nav.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors ${
                  isActive
                    ? "bg-zinc-800 text-lime-300 font-medium"
                    : "text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-200"
                }`
              }
            >
              <Icon className="h-4 w-4 shrink-0" />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-zinc-800 p-3">
          <p className="px-2 text-xs text-zinc-500">Signed in as</p>
          <p className="px-2 text-sm text-zinc-200 truncate">{displayName ?? "Admin"}</p>
          <button
            onClick={() => setPwOpen(true)}
            className="flex w-full items-center gap-2 rounded-lg px-2 py-2 text-sm text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-200"
          >
            <KeyRound className="h-4 w-4" /> Change password
          </button>
          <button
            onClick={() =>
              void signOut().then(() => navigate("/login", { replace: true }))
            }
            className="flex w-full items-center gap-2 rounded-lg px-2 py-2 text-sm text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-200"
          >
            <LogOut className="h-4 w-4" /> Sign out
          </button>
        </div>
      </aside>
      <main className="ml-60 min-w-0 flex-1 px-8 py-8">
        <Outlet />
      </main>
      <ChangePasswordModal open={pwOpen} onClose={() => setPwOpen(false)} />
    </div>
  );
}
