import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { rpc, useList } from "@/lib/api";
import { formatMoney, formatDate, formatDateTime } from "@/lib/format";
import type { Expense } from "@/lib/types";
import {
  Badge, ConfirmDialog, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";

export function DisputesPage() {
  const disputes = useList<Expense[]>(async () => {
    const { data, error } = await supabase
      .from("expenses")
      .select(
        "*, payer:profiles!expenses_payer_id_fkey(display_name), crib:cribs!expenses_crib_id_fkey(name, currency), shares:expense_shares(share_minor, profile:profiles(display_name))",
      )
      .not("disputed_at", "is", null)
      .is("deleted_at", null)
      .order("disputed_at", { ascending: false })
      .limit(200);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as Expense[];
  }, []);

  if (disputes.loading) return <Spinner />;
  if (disputes.error) return <ErrorNote message={disputes.error} onRetry={disputes.reload} />;

  const rows = disputes.data!;
  return (
    <>
      <PageHeader title="Disputes" subtitle="Expenses flagged by members. Resolving clears the flag — the money fields are untouched." />
      {rows.length === 0 ? (
        <EmptyState message="No open disputes." />
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>Description</Th>
              <Th>Crib</Th>
              <Th>Payer</Th>
              <Th className="text-right">Amount</Th>
              <Th>Occurred</Th>
              <Th>Disputed at</Th>
              <Th />
            </tr>
          </thead>
          <tbody>
            {rows.map((e) => (
              <DisputeRow key={e.id} expense={e} onResolve={disputes.reload} />
            ))}
          </tbody>
        </TableWrap>
      )}
    </>
  );
}

function DisputeRow({ expense, onResolve }: { expense: Expense; onResolve: () => void }) {
  const [open, setOpen] = useState(false);
  return (
    <Tr>
      <Td className="max-w-xs truncate">{expense.description}</Td>
      <Td className="text-zinc-400">{expense.crib?.name ?? "—"}</Td>
      <Td className="text-zinc-300">{expense.payer?.display_name ?? "—"}</Td>
      <Td className="text-right whitespace-nowrap">{formatMoney(expense.total_minor, expense.currency)}</Td>
      <Td className="text-zinc-400">{formatDate(expense.occurred_on)}</Td>
      <Td className="text-zinc-400">{formatDateTime(expense.disputed_at)}</Td>
      <Td>
        <button onClick={() => setOpen(true)} className="text-xs text-lime-300 hover:underline">
          resolve
        </button>
        <ConfirmDialog
          open={open}
          title={`Resolve dispute on “${expense.description}”?`}
          body={`The disputed flag is cleared. The amounts stay exactly as they are. Optionally also mark the expense unpaid so the members revisit it.\nShares: ${(expense.shares || []).map((s) => `${s.profile?.display_name ?? s.user_id} ${(s.share_minor / 100).toFixed(2)}`).join(", ") || "n/a"}`}
          confirmLabel="Clear dispute"
          onConfirm={async (reason) => {
            await rpc("admin_resolve_dispute", {
              p_expense_id: expense.id,
              p_unpaid: false,
              p_reason: reason,
            });
            onResolve();
          }}
          onCancel={() => setOpen(false)}
        />
      </Td>
    </Tr>
  );
}

export function DisputeBadge() {
  return <Badge tone="red">disputed</Badge>;
}
