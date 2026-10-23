import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { useList } from "@/lib/api";
import { formatMoney, formatDateTime } from "@/lib/format";
import type { Settlement } from "@/lib/types";
import { EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr } from "@/components/ui";
import { SettlementBadge } from "./UserDetailPage";

const PAGE_SIZE = 50;
const filters = [
  { value: "", label: "All" },
  { value: "confirmed", label: "Confirmed" },
  { value: "pending", label: "Pending" },
  { value: "cancelled", label: "Cancelled" },
  { value: "self_managed", label: "Self-managed" },
] as const;

export function SettlementsPage() {
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [page, setPage] = useState(0);

  const settlements = useList<Settlement[]>(async () => {
    let query = supabase
      .from("settlements")
      .select(
        "*, crib:cribs!settlements_crib_id_fkey(name, currency), from_user:profiles!settlements_from_user_id_fkey(display_name), to_user:profiles!settlements_to_user_id_fkey(display_name)",
        { count: "exact" },
      )
      .order("created_at", { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (statusFilter) query = query.eq("status", statusFilter);
    const { data, error, count } = await query;
    if (error) throw new Error(error.message);
    void count;
    return (data || []) as unknown as Settlement[];
  }, [statusFilter, page]);

  return (
    <>
      <PageHeader title="Settlements" subtitle="Money movement records. Confirmed settlements are immutable by design." />
      <div className="mb-4 flex gap-1">
        {filters.map((f) => (
          <button
            key={f.label}
            onClick={() => {
              setStatusFilter(f.value);
              setPage(0);
            }}
            className={`rounded-full px-3 py-1.5 text-sm ${
              statusFilter === f.value
                ? "bg-lime-300 font-medium text-zinc-950"
                : "border border-zinc-700 text-zinc-300 hover:border-zinc-500"
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {settlements.loading ? (
        <Spinner />
      ) : settlements.error ? (
        <ErrorNote message={settlements.error} onRetry={settlements.reload} />
      ) : settlements.data!.length === 0 ? (
        <EmptyState message="No settlements found." />
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>Crib</Th>
              <Th>From → To</Th>
              <Th className="text-right">Amount</Th>
              <Th>Status</Th>
              <Th>Created</Th>
            </tr>
          </thead>
          <tbody>
            {settlements.data!.map((x) => (
              <Tr key={x.id}>
                <Td className="text-zinc-400">{x.crib?.name ?? "—"}</Td>
                <Td>{x.from_user?.display_name ?? "?"} → {x.to_user?.display_name ?? "?"}</Td>
                <Td className="text-right whitespace-nowrap">{formatMoney(x.amount_minor, x.currency)}</Td>
                <Td><SettlementBadge status={x.status} /></Td>
                <Td className="text-zinc-400">{formatDateTime(x.created_at)}</Td>
              </Tr>
            ))}
          </tbody>
        </TableWrap>
      )}

      <div className="mt-4 flex justify-between">
        <button
          disabled={page === 0 || settlements.loading}
          onClick={() => setPage((p) => p - 1)}
          className="rounded-lg border border-zinc-700 px-3 py-2 text-sm text-zinc-300 hover:border-zinc-500 disabled:opacity-40"
        >
          ← Previous
        </button>
        <button
          disabled={settlements.loading || settlements.data!.length < PAGE_SIZE}
          onClick={() => setPage((p) => p + 1)}
          className="rounded-lg border border-zinc-700 px-3 py-2 text-sm text-zinc-300 hover:border-zinc-500 disabled:opacity-40"
        >
          Next →
        </button>
      </div>
    </>
  );
}
