import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Search } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useList } from "@/lib/api";
import { formatDate, timeAgo } from "@/lib/format";
import type { CribMember, Profile } from "@/lib/types";
import {
  Badge, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";

export function UsersPage() {
  const [search, setSearch] = useState("");

  const users = useList<Profile[]>(async () => {
    const { data, error } = await supabase
      .from("profiles")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(500);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as Profile[];
  }, []);

  const memberships = useList<CribMember[]>(async () => {
    const { data, error } = await supabase
      .from("crib_members")
      .select("crib_id, user_id, left_at")
      .limit(20000);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as CribMember[];
  }, []);

  const cribCounts = useMemo(() => {
    const counts = new Map<string, { total: number; active: number }>();
    for (const m of memberships.data || []) {
      const entry = counts.get(m.user_id) ?? { total: 0, active: 0 };
      entry.total += 1;
      if (!m.left_at) entry.active += 1;
      counts.set(m.user_id, entry);
    }
    return counts;
  }, [memberships.data]);

  const filtered = useMemo(() => {
    if (!search.trim()) return users.data || [];
    const q = search.trim().toLowerCase();
    return (users.data || []).filter((u) => u.display_name.toLowerCase().includes(q));
  }, [users.data, search]);

  return (
    <>
      <PageHeader title="Users" subtitle="Every profile on the platform." />
      <div className="relative mb-4 max-w-sm">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-500" />
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by display name…"
          className="w-full rounded-lg border border-zinc-800 bg-zinc-900 py-2 pl-9 pr-3 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50"
        />
      </div>

      {users.loading || memberships.loading ? (
        <Spinner />
      ) : users.error ? (
        <ErrorNote message={users.error} onRetry={users.reload} />
      ) : filtered.length === 0 ? (
        <EmptyState message="No users match." />
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>Name</Th>
              <Th>Status</Th>
              <Th className="text-center">Cribs</Th>
              <Th>Joined</Th>
              <Th>Last updated</Th>
              <Th>Flags</Th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((u) => (
              <Tr key={u.id}>
                <Td>
                  <Link to={`/users/${u.id}`} className="font-medium text-zinc-100 hover:text-lime-300">
                    {u.display_name}
                  </Link>
                </Td>
                <Td>
                  <StatusBadges user={u} />
                </Td>
                <Td className="text-center text-zinc-300">{cribCounts.get(u.id)?.active ?? 0} active / {cribCounts.get(u.id)?.total ?? 0}</Td>
                <Td className="text-zinc-400">{formatDate(u.created_at)}</Td>
                <Td className="text-zinc-400">{timeAgo(u.updated_at)}</Td>
                <Td>
                  {u.is_admin ? <Badge tone="lime">admin</Badge> : null}
                </Td>
              </Tr>
            ))}
          </tbody>
        </TableWrap>
      )}
    </>
  );
}

export function StatusBadges({ user }: { user: Profile }) {
  return (
    <span className="flex flex-wrap gap-1">
      {user.deleted_at ? <Badge tone="red">deleted</Badge> : user.suspended_at ? <Badge tone="amber">suspended</Badge> : <Badge tone="green">active</Badge>}
    </span>
  );
}
