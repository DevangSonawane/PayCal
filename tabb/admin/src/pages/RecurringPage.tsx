import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { rpc, useList } from "@/lib/api";
import { formatMoney, formatDate } from "@/lib/format";
import type { RecurringSchedule } from "@/lib/types";
import {
  Badge, ConfirmDialog, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";

export function RecurringPage() {
  const schedules = useList<RecurringSchedule[]>(async () => {
    const { data, error } = await supabase
      .from("recurring_schedules")
      .select(
        "*, crib:cribs!recurring_schedules_crib_id_fkey(name, deleted_at), payer:profiles!recurring_schedules_payer_id_fkey(display_name), recipient:profiles!recurring_schedules_recipient_id_fkey(display_name)",
      )
      .order("active", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(300);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as RecurringSchedule[];
  }, []);

  if (schedules.loading) return <Spinner />;
  if (schedules.error) return <ErrorNote message={schedules.error} onRetry={schedules.reload} />;

  const rows = schedules.data!;
  return (
    <>
      <PageHeader title="Recurring schedules" subtitle="Across all cribs. A paused schedule has no assigned payer." />
      {rows.length === 0 ? (
        <EmptyState message="No recurring schedules yet." />
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>Description</Th>
              <Th>Crib</Th>
              <Th>Payer → Recipient</Th>
              <Th className="text-right">Amount</Th>
              <Th>Rule</Th>
              <Th>Status</Th>
              <Th />
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const status = !r.active ? "cancelled" : r.payer_id ? "active" : "paused";
              return (
                <Tr key={r.id}>
                  <Td className="max-w-xs truncate">{r.description}</Td>
                  <Td className="text-zinc-400">{r.crib?.name ?? "—"}</Td>
                  <Td className="text-zinc-300">
                    {r.payer?.display_name ?? "—"} → {r.recipient?.display_name ?? "—"}
                  </Td>
                  <Td className="text-right whitespace-nowrap">{formatMoney(r.amount_minor, r.currency)}</Td>
                  <Td className="text-xs text-zinc-400">
                    {r.frequency} · day {r.anchor_day} · {String(r.local_hour).padStart(2, "0")}:{String(r.local_minute).padStart(2, "0")} {r.time_zone}
                  </Td>
                  <Td>
                    <Badge tone={status === "active" ? "green" : status === "paused" ? "amber" : "gray"}>
                      {status}
                    </Badge>
                    {status === "paused" && r.resume_from && (
                      <p className="mt-0.5 text-xs text-zinc-500">resumes {formatDate(r.resume_from)}</p>
                    )}
                  </Td>
                  <Td>
                    {r.active && !r.crib ? null : r.active ? (
                      <CancelButton schedule={r} onDone={schedules.reload} />
                    ) : null}
                  </Td>
                </Tr>
              );
            })}
          </tbody>
        </TableWrap>
      )}
    </>
  );
}

function CancelButton({ schedule, onDone }: { schedule: RecurringSchedule; onDone: () => void }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)} className="text-xs text-rose-300 hover:underline">cancel</button>
      <ConfirmDialog
        open={open}
        title={`Cancel “${schedule.description}”?`}
        body="Stops the schedule permanently. Already-generated occurrences stay in the ledger."
        confirmLabel="Cancel schedule"
        danger
        onConfirm={async (reason) => {
          await rpc("admin_cancel_schedule", { p_schedule_id: schedule.id, p_reason: reason });
          onDone();
        }}
        onCancel={() => setOpen(false)}
      />
    </>
  );
}
