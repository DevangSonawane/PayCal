import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Trash2 } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { rpc, useList } from "@/lib/api";
import { formatMoney, formatDate, formatDateTime } from "@/lib/format";
import type {
  Crib, CribMember, Expense, Invitation, Profile, RecurringSchedule, Settlement,
} from "@/lib/types";
import {
  Badge, ConfirmDialog, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";
import { SettlementBadge } from "./UserDetailPage";

const tabs = ["Members", "Expenses", "Settlements", "Schedules", "Invitations"] as const;
type Tab = (typeof tabs)[number];

export function CribDetailPage() {
  const { id = "" } = useParams();
  const [tab, setTab] = useState<Tab>("Members");
  const [deleteOpen, setDeleteOpen] = useState(false);

  const crib = useList<Crib>(async () => {
    const { data, error } = await supabase
      .from("cribs")
      .select("*, owner:profiles!cribs_owner_id_fkey(display_name)")
      .eq("id", id)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return (data ?? null) as unknown as Crib;
  }, [id]);

  if (crib.loading) return <Spinner />;
  if (crib.error) return <ErrorNote message={crib.error} onRetry={crib.reload} />;
  if (!crib.data) return <EmptyState message="Crib not found." />;

  const c = crib.data;

  return (
    <>
      <Link to="/cribs" className="mb-4 inline-flex items-center gap-1 text-sm text-zinc-400 hover:text-zinc-200">
        <ArrowLeft className="h-4 w-4" /> Cribs
      </Link>
      <PageHeader
        title={c.name}
        subtitle={`Owner: ${c.owner?.display_name ?? "unknown"} · ${c.currency} · version ${c.version} · created ${formatDate(c.created_at)}`}
      >
        {!c.deleted_at && (
          <button
            onClick={() => setDeleteOpen(true)}
            className="flex items-center gap-2 rounded-lg border border-rose-400/40 px-3 py-2 text-sm text-rose-300 hover:bg-rose-400/10"
          >
            <Trash2 className="h-4 w-4" /> Delete crib
          </button>
        )}
      </PageHeader>

      {c.deleted_at && (
        <div className="mb-6 rounded-lg border border-rose-400/20 bg-rose-400/10 px-4 py-3 text-sm text-rose-200">
          Crib deleted {formatDateTime(c.deleted_at)}. The expenses and settlements below stay in the ledger (orphaned rows).
        </div>
      )}

      <div className="mb-4 flex gap-1 border-b border-zinc-800">
        {tabs.map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-2 text-sm transition-colors ${
              tab === t
                ? "border-b-2 border-lime-300 font-medium text-zinc-100"
                : "text-zinc-400 hover:text-zinc-200"
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === "Members" && <MembersTab cribId={id} ownerId={c.owner_id} deleted={!!c.deleted_at} onCribChanged={crib.reload} />}
      {tab === "Expenses" && <ExpensesTab cribId={id} />}
      {tab === "Settlements" && <SettlementsTab cribId={id} />}
      {tab === "Schedules" && <SchedulesTab cribId={id} deleted={!!c.deleted_at} />}
      {tab === "Invitations" && <InvitationsTab cribId={id} deleted={!!c.deleted_at} />}

      <ConfirmDialog
        open={deleteOpen}
        title={`Delete ${c.name}?`}
        body={`Soft-deletes the crib (version ${c.version}). Its members lose access, but all expenses and settlements stay in the ledger. This is visible to the owner as a dead crib and can be reversed only with a DB write.`}
        confirmLabel="Delete crib"
        danger
        requireReason
        onConfirm={async (reason) => {
          await rpc("admin_delete_crib", { p_crib_id: c.id, p_expected_version: c.version, p_reason: reason });
          crib.reload();
        }}
        onCancel={() => setDeleteOpen(false)}
      />
    </>
  );
}

function MembersTab({
  cribId, ownerId, deleted, onCribChanged,
}: {
  cribId: string;
  ownerId: string;
  deleted: boolean;
  onCribChanged: () => void;
}) {
  const members = useList<(CribMember & { profile?: Profile })[]>(async () => {
    const { data, error } = await supabase
      .from("crib_members")
      .select("*, profile:profiles!crib_members_user_id_fkey(display_name, suspended_at, deleted_at)")
      .eq("crib_id", cribId)
      .order("joined_at");
    if (error) throw new Error(error.message);
    return (data || []) as unknown as (CribMember & { profile?: Profile })[];
  }, [cribId]);

  if (members.loading) return <Spinner />;
  if (members.error) return <ErrorNote message={members.error} onRetry={members.reload} />;
  if (members.data!.length === 0) return <EmptyState message="No members." />;

  return (
    <TableWrap>
      <thead>
        <tr><Th>Member</Th><Th>Role</Th><Th>Status</Th><Th>Joined</Th><Th>Left</Th><Th /></tr>
      </thead>
      <tbody>
        {members.data!.map((m) => (
          <Tr key={m.user_id}>
            <Td>
              <Link to={`/users/${m.user_id}`} className="text-zinc-100 hover:text-lime-300">
                {m.profile?.display_name ?? m.user_id}
              </Link>
            </Td>
            <Td>{m.user_id === ownerId ? <Badge tone="violet">owner</Badge> : <Badge tone="gray">member</Badge>}</Td>
            <Td>
              {!m.left_at ? (
                m.profile?.deleted_at ? <Badge tone="red">deleted</Badge>
                : m.profile?.suspended_at ? <Badge tone="amber">suspended</Badge>
                : <Badge tone="green">active</Badge>
              ) : <Badge tone="gray">departed</Badge>}
            </Td>
            <Td className="text-zinc-400">{formatDate(m.joined_at)}</Td>
            <Td className="text-zinc-400">{formatDate(m.left_at)}</Td>
            <Td>
              {!m.left_at && !deleted && m.user_id !== ownerId ? (
                <RemoveButton cribId={cribId} userId={m.user_id} userName={m.profile?.display_name ?? "member"} onDone={() => { members.reload(); onCribChanged(); }} />
              ) : null}
            </Td>
          </Tr>
        ))}
      </tbody>
    </TableWrap>
  );
}

function RemoveButton({
  cribId, userId, userName, onDone,
}: {
  cribId: string;
  userId: string;
  userName: string;
  onDone: () => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)} className="text-xs text-rose-300 hover:underline">remove</button>
      <ConfirmDialog
        open={open}
        title={`Remove ${userName}?`}
        body="Soft-ends the membership. History and balances are preserved."
        confirmLabel="Remove"
        danger
        onConfirm={async (reason) => {
          await rpc("admin_remove_crib_member", { p_crib_id: cribId, p_user_id: userId, p_reason: reason });
          onDone();
        }}
        onCancel={() => setOpen(false)}
      />
    </>
  );
}

function ExpensesTab({ cribId }: { cribId: string }) {
  const expenses = useList<Expense[]>(async () => {
    const { data, error } = await supabase
      .from("expenses")
      .select(
        "*, payer:profiles!expenses_payer_id_fkey(display_name), shares:expense_shares(share_minor, profile:profiles(display_name))",
      )
      .eq("crib_id", cribId)
      .order("occurred_on", { ascending: false })
      .limit(200);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as Expense[];
  }, [cribId]);

  if (expenses.loading) return <Spinner />;
  if (expenses.error) return <ErrorNote message={expenses.error} onRetry={expenses.reload} />;
  const rows = expenses.data!;
  if (rows.length === 0) return <EmptyState message="No expenses in this crib." />;

  return (
    <TableWrap>
      <thead>
        <tr><Th>Description</Th><Th>Payer</Th><Th className="text-right">Amount</Th><Th>Date</Th><Th>Status</Th></tr>
      </thead>
      <tbody>
        {rows.map((e) => (
          <Tr key={e.id}>
            <Td className="max-w-xs truncate">{e.description}</Td>
            <Td className="text-zinc-300">{e.payer?.display_name ?? "—"}</Td>
            <Td className="text-right">{formatMoney(e.total_minor, e.currency)}</Td>
            <Td className="text-zinc-400">{formatDate(e.occurred_on)}</Td>
            <Td>
              <span className="flex gap-1">
                {e.disputed_at && <Badge tone="red">disputed</Badge>}
                {e.unpaid && <Badge tone="amber">unpaid</Badge>}
                {e.deleted_at && <Badge tone="gray">deleted</Badge>}
              </span>
            </Td>
          </Tr>
        ))}
      </tbody>
    </TableWrap>
  );
}

function SettlementsTab({ cribId }: { cribId: string }) {
  const settlements = useList<Settlement[]>(async () => {
    const { data, error } = await supabase
      .from("settlements")
      .select(
        "*, from_user:profiles!settlements_from_user_id_fkey(display_name), to_user:profiles!settlements_to_user_id_fkey(display_name)",
      )
      .eq("crib_id", cribId)
      .order("created_at", { ascending: false })
      .limit(200);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as Settlement[];
  }, [cribId]);

  if (settlements.loading) return <Spinner />;
  if (settlements.error) return <ErrorNote message={settlements.error} onRetry={settlements.reload} />;
  if (settlements.data!.length === 0) return <EmptyState message="No settlements in this crib." />;

  return (
    <TableWrap>
      <thead>
        <tr><Th>From → To</Th><Th className="text-right">Amount</Th><Th>Status</Th><Th>Created</Th></tr>
      </thead>
      <tbody>
        {settlements.data!.map((x) => (
          <Tr key={x.id}>
            <Td>{x.from_user?.display_name ?? "?"} → {x.to_user?.display_name ?? "?"}</Td>
            <Td className="text-right">{formatMoney(x.amount_minor, x.currency)}</Td>
            <Td><SettlementBadge status={x.status} /></Td>
            <Td className="text-zinc-400">{formatDateTime(x.created_at)}</Td>
          </Tr>
        ))}
      </tbody>
    </TableWrap>
  );
}

function SchedulesTab({ cribId, deleted }: { cribId: string; deleted: boolean }) {
  const schedules = useList<RecurringSchedule[]>(async () => {
    const { data, error } = await supabase
      .from("recurring_schedules")
      .select(
        "*, payer:profiles!recurring_schedules_payer_id_fkey(display_name), recipient:profiles!recurring_schedules_recipient_id_fkey(display_name)",
      )
      .eq("crib_id", cribId)
      .order("created_at", { ascending: false });
    if (error) throw new Error(error.message);
    return (data || []) as unknown as RecurringSchedule[];
  }, [cribId]);

  if (schedules.loading) return <Spinner />;
  if (schedules.error) return <ErrorNote message={schedules.error} onRetry={schedules.reload} />;
  if (schedules.data!.length === 0) return <EmptyState message="No recurring schedules in this crib." />;

  return (
    <TableWrap>
      <thead>
        <tr><Th>Description</Th><Th>Payer → Recipient</Th><Th className="text-right">Amount</Th><Th>Rule</Th><Th>Status</Th><Th /></tr>
      </thead>
      <tbody>
        {schedules.data!.map((r) => {
          const status = !r.active ? "cancelled" : r.payer_id ? "active" : "paused";
          return (
            <Tr key={r.id}>
              <Td>{r.description}</Td>
              <Td className="text-zinc-300">{r.payer?.display_name ?? "—"} → {r.recipient?.display_name ?? "—"}</Td>
              <Td className="text-right">{formatMoney(r.amount_minor, r.currency)}</Td>
              <Td className="text-zinc-400 text-xs">
                {r.frequency}, day {r.anchor_day} at {String(r.local_hour).padStart(2, "0")}:{String(r.local_minute).padStart(2, "0")} {r.time_zone}
              </Td>
              <Td>
                <Badge tone={status === "active" ? "green" : status === "paused" ? "amber" : "gray"}>{status}</Badge>
              </Td>
              <Td>
                {!deleted && status !== "cancelled" ? <CancelButton schedule={r} onDone={schedules.reload} /> : null}
              </Td>
            </Tr>
          );
        })}
      </tbody>
    </TableWrap>
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
        body={`Stops the schedule for good. Occurrences already generated stay in the ledger. ${schedule.payer_id ? "" : "The schedule is currently paused."}`}
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

function InvitationsTab({ cribId, deleted }: { cribId: string; deleted: boolean }) {
  const invitations = useList<(Invitation & { creator?: Profile })[]>(async () => {
    const { data, error } = await supabase
      .from("invitations")
      .select("*, creator:profiles!invitations_created_by_fkey(display_name)")
      .eq("crib_id", cribId)
      .order("created_at", { ascending: false })
      .limit(100);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as (Invitation & { creator?: Profile })[];
  }, [cribId]);

  if (invitations.loading) return <Spinner />;
  if (invitations.error) return <ErrorNote message={invitations.error} onRetry={invitations.reload} />;
  if (invitations.data!.length === 0) return <EmptyState message="No invitations for this crib." />;

  return (
    <TableWrap>
      <thead>
        <tr><Th>Created by</Th><Th>Created</Th><Th>Expires</Th><Th>Status</Th><Th /></tr>
      </thead>
      <tbody>
        {invitations.data!.map((i) => {
          const status =
            i.revoked_at ? "revoked" :
            i.accepted_at ? "accepted" :
            new Date(i.expires_at) < new Date() ? "expired" : "open";
          return (
            <Tr key={i.id}>
              <Td className="text-zinc-300">{i.creator?.display_name ?? "—"}</Td>
              <Td className="text-zinc-400">{formatDateTime(i.created_at)}</Td>
              <Td className="text-zinc-400">{formatDateTime(i.expires_at)}</Td>
              <Td>
                <Badge tone={status === "open" ? "green" : status === "accepted" ? "blue" : "gray"}>{status}</Badge>
              </Td>
              <Td>
                {!deleted && status === "open" ? <RevokeButton invitation={i} onDone={invitations.reload} /> : null}
              </Td>
            </Tr>
          );
        })}
      </tbody>
    </TableWrap>
  );
}

function RevokeButton({ invitation, onDone }: { invitation: Invitation; onDone: () => void }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)} className="text-xs text-rose-300 hover:underline">revoke</button>
      <ConfirmDialog
        open={open}
        title="Revoke invitation?"
        body={`The token ${invitation.token_hash.slice(0, 8)}… can no longer be accepted by anyone.`}
        confirmLabel="Revoke"
        danger
        onConfirm={async (reason) => {
          await rpc("admin_revoke_invitation", { p_invitation_id: invitation.id, p_reason: reason });
          onDone();
        }}
        onCancel={() => setOpen(false)}
      />
    </>
  );
}
