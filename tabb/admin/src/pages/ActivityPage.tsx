import { supabase } from "@/lib/supabase";
import { useList } from "@/lib/api";
import { formatDateTime } from "@/lib/format";
import type { ActivityEvent } from "@/lib/types";
import {
  Badge, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";

export function ActivityPage() {
  const events = useList<ActivityEvent[]>(async () => {
    const { data, error } = await supabase
      .from("activity_events")
      .select(
        "*, crib:cribs!activity_events_crib_id_fkey(name), actor:profiles!activity_events_actor_id_fkey(display_name)",
      )
      .order("occurred_at", { ascending: false })
      .limit(200);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as ActivityEvent[];
  }, []);

  if (events.loading) return <Spinner />;
  if (events.error) return <ErrorNote message={events.error} onRetry={events.reload} />;

  const rows = events.data!;
  return (
    <>
      <PageHeader title="Activity feed" subtitle="The latest 200 events across every crib." />
      {rows.length === 0 ? (
        <EmptyState message="No activity yet." />
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>When</Th>
              <Th>Crib</Th>
              <Th>Actor</Th>
              <Th>Action</Th>
              <Th>Metadata</Th>
            </tr>
          </thead>
          <tbody>
            {rows.map((e) => (
              <Tr key={e.id}>
                <Td className="whitespace-nowrap text-zinc-400">{formatDateTime(e.occurred_at)}</Td>
                <Td>{e.crib?.name ?? "—"}</Td>
                <Td className="text-zinc-300">{e.actor?.display_name ?? "system"}</Td>
                <Td><Badge tone="blue">{e.action}</Badge></Td>
                <Td className="max-w-md">
                  <code className="text-xs text-zinc-400">
                    {Object.keys(e.metadata || {}).length === 0
                      ? "{}"
                      : JSON.stringify(e.metadata)}
                  </code>
                </Td>
              </Tr>
            ))}
          </tbody>
        </TableWrap>
      )}
    </>
  );
}
