import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Search } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useList } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type { Crib, CribMember } from "@/lib/types";
import {
  Badge, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";

export function CribsPage() {
  const [search, setSearch] = useState("");

  const cribs = useList<Crib[]>(async () => {
    const { data, error } = await supabase
      .from("cribs")
      .select("*, owner:profiles!cribs_owner_id_fkey(display_name)")
      .order("created_at", { ascending: false })
      .limit(500);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as Crib[];
  }, []);

  const memberships = useList<CribMember[]>(async () => {
    const { data, error } = await supabase
      .from("crib_members")
      .select("crib_id, user_id, left_at")
      .limit(20000);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as CribMember[];
  }, []);

  const memberCounts = useMemo(() => {
    const map = new Map<string, { total: number; active: number }>();
    for (const m of memberships.data || []) {
      const entry = map.get(m.crib_id) ?? { total: 0, active: 0 };
      entry.total += 1;
      if (!m.left_at) entry.active += 1;
      map.set(m.crib_id, entry);
    }
    return map;
  }, [memberships.data]);

  const filtered = useMemo(() => {
    if (!search.trim()) return cribs.data || [];
    const q = search.trim().toLowerCase();
    return (cribs.data || []).filter(
      (c) => c.name.toLowerCase().includes(q) || c.owner?.display_name.toLowerCase().includes(q),
    );
  }, [cribs.data, search]);

  const live = filtered.filter((c) => !c.deleted_at);
  const deleted = filtered.filter((c) => c.deleted_at);

  return (
    <>
      <PageHeader title="Cribs" subtitle="Shared ledgers. Deleted cribs keep their financial history." />
      <div className="relative mb-4 max-w-sm">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-500" />
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by crib or owner name…"
          className="w-full rounded-lg border border-zinc-800 bg-zinc-900 py-2 pl-9 pr-3 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50"
        />
      </div>

      {cribs.loading || memberships.loading ? (
        <Spinner />
      ) : cribs.error ? (
        <ErrorNote message={cribs.error} onRetry={cribs.reload} />
      ) : filtered.length === 0 ? (
        <EmptyState message="No cribs match." />
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>Name</Th>
              <Th>Owner</Th>
              <Th>Members</Th>
              <Th>Currency</Th>
              <Th>Status</Th>
              <Th>Created</Th>
            </tr>
          </thead>
          <tbody>
            {live.map((c) => (
              <Tr key={c.id}>
                <Td>
                  <Link to={`/cribs/${c.id}`} className="font-medium text-zinc-100 hover:text-lime-300">
                    {c.name}
                  </Link>
                </Td>
                <Td>{c.owner?.display_name ?? "—"}</Td>
                <Td className="text-zinc-300">
                  {memberCounts.get(c.id)?.active ?? 0} active / {memberCounts.get(c.id)?.total ?? 0}
                </Td>
                <Td className="text-zinc-400">{c.currency}</Td>
                <Td><Badge tone="green">live</Badge></Td>
                <Td className="text-zinc-400">{formatDate(c.created_at)}</Td>
              </Tr>
            ))}
            {deleted.map((c) => (
              <Tr key={c.id}>
                <Td>
                  <Link to={`/cribs/${c.id}`} className="font-medium text-zinc-500 line-through hover:text-zinc-400">
                    {c.name}
                  </Link>
                </Td>
                <Td className="text-zinc-500">{c.owner?.display_name ?? "—"}</Td>
                <Td className="text-zinc-500">
                  {memberCounts.get(c.id)?.active ?? 0} active / {memberCounts.get(c.id)?.total ?? 0}
                </Td>
                <Td className="text-zinc-500">{c.currency}</Td>
                <Td><Badge tone="red">deleted {formatDate(c.deleted_at)}</Badge></Td>
                <Td className="text-zinc-500">{formatDate(c.created_at)}</Td>
              </Tr>
            ))}
          </tbody>
        </TableWrap>
      )}
    </>
  );
}
