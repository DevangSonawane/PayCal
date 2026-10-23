import { Link } from "react-router-dom";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { formatMoney, formatDateTime } from "@/lib/format";
import { rpc, useList } from "@/lib/api";
import { supabase } from "@/lib/supabase";
import type { ActivityEvent, DashboardStats } from "@/lib/types";
import { Badge, Card, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr } from "@/components/ui";

interface StatCard {
  label: string;
  value: string;
  sub: string;
  to: string;
}

export function DashboardPage() {
  const stats = useList<DashboardStats>(() => rpc("admin_dashboard_stats"), []);
  const events = useList<ActivityEvent[]>(
    () =>
      supabaseActivityList(50),
    [],
  );

  if (stats.loading) return <Spinner />;
  if (stats.error) return <ErrorNote message={stats.error} onRetry={stats.reload} />;
  if (!stats.data) return <EmptyState message="No stats available." />;

  const s = stats.data;

  const cards: StatCard[] = [
    { label: "Users", value: String(s.profiles_total), sub: `${s.profiles_suspended} suspended · ${s.profiles_deleted} deleted`, to: "/users" },
    { label: "Live cribs", value: String(s.cribs_live), sub: `${s.cribs_deleted} deleted`, to: "/cribs" },
    { label: "Active members", value: String(s.members_active), sub: `${s.members_departed} departed memberships`, to: "/cribs" },
    { label: "Expenses (all time)", value: String(s.expenses_total), sub: `${s.expenses_last_30d} in last 30 days`, to: "/expenses" },
    { label: "Open disputes", value: String(s.disputed_open), sub: `${s.expenses_unpaid} unpaid expenses`, to: "/disputes" },
    { label: "Confirmed settlements", value: String(s.settlements_confirmed), sub: volumeLine(s.currency_totals), to: "/settlements" },
    { label: "Schedules", value: String(s.schedules_active), sub: `${s.schedules_paused} paused · ${s.schedules_cancelled} cancelled`, to: "/recurring" },
    { label: "Push outbox pending", value: String(s.outbox_pending), sub: `${s.invitations_open} open invitations`, to: "/activity" },
  ];

  return (
    <>
      <PageHeader title="Overview" subtitle="Platform-wide numbers for the whole of PayCal." />
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {cards.map((c) => (
          <Link key={c.label} to={c.to}>
            <Card className="p-4 transition-colors hover:border-zinc-600">
              <p className="text-xs font-medium uppercase tracking-wide text-zinc-500">{c.label}</p>
              <p className="mt-2 text-3xl font-semibold text-zinc-50">{c.value}</p>
              <p className="mt-1 text-xs text-zinc-400">{c.sub}</p>
            </Card>
          </Link>
        ))}
      </div>

      <Card className="mt-6 p-4">
        <p className="text-sm font-medium text-zinc-200">Expenses per day · last 30 days</p>
        <div className="mt-4 h-64">
          {s.expenses_per_day.length === 0 ? (
            <EmptyState message="No expenses in the last 30 days." />
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={s.expenses_per_day} margin={{ top: 4, right: 8, left: 8, bottom: 0 }}>
                <CartesianGrid stroke="#27272a" vertical={false} />
                <XAxis
                  dataKey="day"
                  tick={{ fill: "#71717a", fontSize: 11 }}
                  tickFormatter={(v: string) => v.slice(5)}
                  stroke="#3f3f46"
                />
                <YAxis tick={{ fill: "#71717a", fontSize: 11 }} stroke="#3f3f46" allowDecimals={false} />
                <Tooltip
                  contentStyle={{ background: "#18181b", border: "1px solid #3f3f46", borderRadius: 8 }}
                  labelStyle={{ color: "#a1a1aa" }}
                  formatter={(value, name) =>
                    name === "total_minor" ? [formatMoney(Number(value), "USD") + " (mixed currencies)", "Volume"] : [value, "Count"]
                  }
                />
                <Bar dataKey="count" fill="#a3e635" radius={[3, 3, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
      </Card>

      <div className="mt-6 flex items-center justify-between">
        <h2 className="text-lg font-semibold text-zinc-100">Recent activity</h2>
        <Link to="/activity" className="text-sm text-lime-300 hover:underline">
          View all →
        </Link>
      </div>
      <div className="mt-3">
        {events.loading ? (
          <Spinner />
        ) : events.error ? (
          <ErrorNote message={events.error} onRetry={events.reload} />
        ) : (
          <TableWrap>
            <thead>
              <tr>
                <Th>When</Th>
                <Th>Crib</Th>
                <Th>Actor</Th>
                <Th>Action</Th>
              </tr>
            </thead>
            <tbody>
              {(events.data || []).map((e) => (
                <Tr key={e.id}>
                  <Td className="whitespace-nowrap text-zinc-400">{formatDateTime(e.occurred_at)}</Td>
                  <Td>{e.crib?.name ?? "—"}</Td>
                  <Td>{e.actor?.display_name ?? "system"}</Td>
                  <Td><Badge tone="blue">{e.action}</Badge></Td>
                </Tr>
              ))}
            </tbody>
          </TableWrap>
        )}
      </div>
    </>
  );
}

function volumeLine(totals: { currency: string; expenses_minor: number; settlements_minor: number }[]): string {
  if (totals.length === 0) return "no financial volume yet";
  return totals
    .map((t) => `${formatMoney(t.settlements_minor, t.currency)}`)
    .join(" · ");
}

async function supabaseActivityList(limit: number): Promise<ActivityEvent[]> {
  const { data, error } = await supabase
    .from("activity_events")
    .select("*, crib:cribs!activity_events_crib_id_fkey(name), actor:profiles!activity_events_actor_id_fkey(display_name)")
    .order("occurred_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return (data || []) as unknown as ActivityEvent[];
}
