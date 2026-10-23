import { useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useList } from "@/lib/api";
import { formatMoney, formatDate } from "@/lib/format";
import type { Expense } from "@/lib/types";
import {
  Badge, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";

const PAGE_SIZE = 50;

export function ExpensesPage() {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(0);

  const expenses = useList<Expense[]>(async () => {
    let query = supabase
      .from("expenses")
      .select(
        "*, payer:profiles!expenses_payer_id_fkey(display_name), crib:cribs!expenses_crib_id_fkey(name, currency), shares:expense_shares(share_minor, profile:profiles(display_name))",
        { count: "exact" },
      )
      .is("deleted_at", null)
      .order("occurred_on", { ascending: false })
      .order("created_at", { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (search.trim()) query = query.ilike("description", `%${search.trim()}%`);
    const { data, error, count } = await query;
    if (error) throw new Error(error.message);
    void count;
    return (data || []) as unknown as Expense[];
  }, [page, search]);

  const total = useMemo(
    () => (expenses.data || []).reduce((sum, e) => sum + e.total_minor, 0),
    [expenses.data],
  );

  return (
    <>
      <PageHeader
        title="Expenses"
        subtitle={`Page ${page + 1} · page volume ${(total / 100).toFixed(2)} (mixed currencies)`}
      />
      <div className="mb-4 max-w-sm">
        <input
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(0);
          }}
          placeholder="Search by description…"
          className="w-full rounded-lg border border-zinc-800 bg-zinc-900 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-lime-300/50"
        />
      </div>

      {expenses.loading ? (
        <Spinner />
      ) : expenses.error ? (
        <ErrorNote message={expenses.error} onRetry={expenses.reload} />
      ) : expenses.data!.length === 0 ? (
        <EmptyState message="No expenses found." />
      ) : (
        <ExpenseTable rows={expenses.data!} />
      )}

      <div className="mt-4 flex justify-between">
        <button
          disabled={page === 0 || expenses.loading}
          onClick={() => setPage((p) => p - 1)}
          className="rounded-lg border border-zinc-700 px-3 py-2 text-sm text-zinc-300 hover:border-zinc-500 disabled:opacity-40"
        >
          ← Previous
        </button>
        <button
          disabled={expenses.loading || expenses.data!.length < PAGE_SIZE}
          onClick={() => setPage((p) => p + 1)}
          className="rounded-lg border border-zinc-700 px-3 py-2 text-sm text-zinc-300 hover:border-zinc-500 disabled:opacity-40"
        >
          Next →
        </button>
      </div>
    </>
  );
}

export function ExpenseTable({ rows }: { rows: Expense[] }) {
  return (
    <TableWrap>
      <thead>
        <tr>
          <Th>Description</Th>
          <Th>Crib</Th>
          <Th>Payer</Th>
          <Th className="text-right">Amount</Th>
          <Th>Date</Th>
          <Th>Status</Th>
        </tr>
      </thead>
      <tbody>
        {rows.map((e) => (
          <Tr key={e.id}>
            <Td className="max-w-xs truncate">{e.description}</Td>
            <Td className="text-zinc-400">{e.crib?.name ?? "—"}</Td>
            <Td className="text-zinc-300">{e.payer?.display_name ?? "—"}</Td>
            <Td className="text-right whitespace-nowrap">{formatMoney(e.total_minor, e.currency)}</Td>
            <Td className="text-zinc-400">{formatDate(e.occurred_on)}</Td>
            <Td>
              <span className="flex gap-1">
                {e.disputed_at && <Badge tone="red">disputed</Badge>}
                {e.unpaid && <Badge tone="amber">unpaid</Badge>}
                {!e.disputed_at && !e.unpaid && <span className="text-zinc-500">—</span>}
              </span>
            </Td>
          </Tr>
        ))}
      </tbody>
    </TableWrap>
  );
}
