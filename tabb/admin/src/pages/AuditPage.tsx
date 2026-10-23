import { supabase } from "@/lib/supabase";
import { useList } from "@/lib/api";
import { formatDateTime } from "@/lib/format";
import type { AuditLogRow } from "@/lib/types";
import {
  Badge, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";

export function AuditPage() {
  const rows = useList<AuditLogRow[]>(async () => {
    const { data, error } = await supabase
      .from("admin_audit_log")
      .select("*, admin:profiles!admin_audit_log_admin_id_fkey(display_name)")
      .order("created_at", { ascending: false })
      .limit(200);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as AuditLogRow[];
  }, []);

  if (rows.loading) return <Spinner />;
  if (rows.error) return <ErrorNote message={rows.error} onRetry={rows.reload} />;

  const list = rows.data!;
  return (
    <>
      <PageHeader title="Admin audit log" subtitle="Every admin action with its author and reason." />
      {list.length === 0 ? (
        <EmptyState message="No admin actions recorded yet." />
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>When</Th>
              <Th>Admin</Th>
              <Th>Action</Th>
              <Th>Target</Th>
              <Th>Reason</Th>
              <Th>Details</Th>
            </tr>
          </thead>
          <tbody>
            {list.map((r) => (
              <Tr key={r.id}>
                <Td className="whitespace-nowrap text-zinc-400">{formatDateTime(r.created_at)}</Td>
                <Td className="text-zinc-200">{r.admin?.display_name ?? r.admin_id}</Td>
                <Td><Badge tone="violet">{r.action}</Badge></Td>
                <Td>
                  {r.target_type}
                  {r.target_id ? (
                    <span className="block max-w-[12rem] truncate text-xs text-zinc-500">{r.target_id}</span>
                  ) : null}
                </Td>
                <Td className="max-w-xs text-zinc-400">{r.reason || "—"}</Td>
                <Td className="max-w-md">
                  <code className="text-xs text-zinc-500">
                    {Object.keys(r.details || {}).length === 0 ? "{}" : JSON.stringify(r.details)}
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
