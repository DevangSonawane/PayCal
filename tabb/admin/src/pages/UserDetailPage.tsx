import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Ban, ShieldOff } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { rpc, useList } from "@/lib/api";
import { formatMoney, formatDate, formatDateTime } from "@/lib/format";
import type { Crib, CribMember, Expense, Profile, Settlement } from "@/lib/types";
import {
  Badge, ConfirmDialog, EmptyState, ErrorNote, PageHeader, Spinner, TableWrap, Td, Th, Tr,
} from "@/components/ui";
import { StatusBadges } from "./UsersPage";

export function UserDetailPage() {
  const { id = "" } = useParams();
  const [suspendOpen, setSuspendOpen] = useState(false);
  const [unsuspendOpen, setUnsuspendOpen] = useState(false);

  const user = useList<Profile>(async () => {
    const { data, error } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", id)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return (data ?? null) as unknown as Profile;
  }, [id]);

  const memberships = useList<(CribMember & { crib?: Crib })[]>(async () => {
    const { data, error } = await supabase
      .from("crib_members")
      .select("*, crib:cribs!crib_members_crib_id_fkey(id, name, currency, owner_id, deleted_at)")
      .eq("user_id", id)
      .order("joined_at", { ascending: false });
    if (error) throw new Error(error.message);
    return (data || []) as unknown as (CribMember & { crib?: Crib })[];
  }, [id]);

  const paid = useList<Expense[]>(async () => {
    const { data, error } = await supabase
      .from("expenses")
      .select("*, crib:cribs!expenses_crib_id_fkey(name, currency)")
      .eq("payer_id", id)
      .is("deleted_at", null)
      .order("occurred_on", { ascending: false })
      .limit(25);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as Expense[];
  }, [id]);

  const settlements = useList<Settlement[]>(async () => {
    const { data, error } = await supabase
      .from("settlements")
      .select("*, crib:cribs!settlements_crib_id_fkey(name, currency)")
      .or(`from_user_id.eq.${id},to_user_id.eq.${id}`)
      .order("created_at", { ascending: false })
      .limit(25);
    if (error) throw new Error(error.message);
    return (data || []) as unknown as Settlement[];
  }, [id]);

  if (user.loading) return <Spinner />;
  if (user.error) return <ErrorNote message={user.error} onRetry={user.reload} />;
  if (!user.data) return <EmptyState message="User not found (may be deleted or blocked)." />;

  const u = user.data;
  const suspended = !!u.suspended_at;

  const doSuspend = async (reason: string) => {
    await rpc("admin_set_user_suspension", {
      p_target_user_id: u.id,
      p_suspended: true,
      p_reason: reason,
    });
    user.reload();
    memberships.reload();
  };

  return (
    <>
      <Link to="/users" className="mb-4 inline-flex items-center gap-1 text-sm text-zinc-400 hover:text-zinc-200">
        <ArrowLeft className="h-4 w-4" /> Users
      </Link>
      <PageHeader title={u.display_name} subtitle={`id ${u.id}`}>
        <a
          href={`https://supabase.com/dashboard/project/_/editor/profiles?filter=id%3Aeq%3A${u.id}`}
          target="_blank"
          rel="noreferrer"
          className="rounded-lg border border-zinc-700 px-3 py-2 text-sm text-zinc-300 hover:border-zinc-500"
        >
          Open in Supabase
        </a>
        {u.deleted_at ? null : suspended ? (
          <button
            onClick={() => setUnsuspendOpen(true)}
            className="flex items-center gap-2 rounded-lg border border-amber-400/40 px-3 py-2 text-sm text-amber-300 hover:bg-amber-400/10"
          >
            <ShieldOff className="h-4 w-4" /> Unsuspend
          </button>
        ) : (
          <button
            onClick={() => setSuspendOpen(true)}
            className="flex items-center gap-2 rounded-lg border border-rose-400/40 px-3 py-2 text-sm text-rose-300 hover:bg-rose-400/10"
          >
            <Ban className="h-4 w-4" /> Suspend
          </button>
        )}
      </PageHeader>

      <div className="mb-6 flex flex-wrap gap-2">
        <StatusBadges user={u} />
        {u.is_admin && <Badge tone="lime">platform admin</Badge>}
        <Badge tone="gray">joined {formatDate(u.created_at)}</Badge>
      </div>

      {u.suspended_at && (
        <div className="mb-6 rounded-lg border border-amber-400/20 bg-amber-400/10 px-4 py-3 text-sm text-amber-200">
          Suspended {formatDateTime(u.suspended_at)}
          {u.suspension_reason ? ` — “${u.suspension_reason}”` : ""}
        </div>
      )}
      {u.deleted_at && (
        <div className="mb-6 rounded-lg border border-rose-400/20 bg-rose-400/10 px-4 py-3 text-sm text-rose-200">
          Account deleted {formatDateTime(u.deleted_at)} (anonymised by the app’s deletion flow).
        </div>
      )}

      <section className="mt-2">
        <h2 className="mb-3 text-lg font-semibold text-zinc-100">Memberships</h2>
        {memberships.loading ? <Spinner /> : memberships.error ? (
          <ErrorNote message={memberships.error} onRetry={memberships.reload} />
        ) : memberships.data!.length === 0 ? (
          <EmptyState message="No memberships." />
        ) : (
          <TableWrap>
            <thead>
              <tr><Th>Crib</Th><Th>Owner</Th><Th>Joined</Th><Th>Left</Th><Th /></tr>
            </thead>
            <tbody>
              {memberships.data!.map((m) => (
                <Tr key={`${m.crib_id}:${m.user_id}`}>
                  <Td>
                    {m.crib ? (
                      <Link to={`/cribs/${m.crib_id}`} className={m.crib.deleted_at ? "text-zinc-500 line-through" : "text-zinc-100 hover:text-lime-300"}>
                        {m.crib.name}
                      </Link>
                    ) : "—"}
                  </Td>
                  <Td>{m.crib?.owner_id === m.user_id ? <Badge tone="violet">owner</Badge> : <Badge tone="gray">member</Badge>}</Td>
                  <Td className="text-zinc-400">{formatDate(m.joined_at)}</Td>
                  <Td className="text-zinc-400">{formatDate(m.left_at)}</Td>
                  <Td>
                    {!m.left_at && m.crib && !m.crib.deleted_at && !suspended ? (
                      <RemoveMemberButton cribId={m.crib_id} cribName={m.crib.name} userId={u.id} userName={u.display_name} onDone={() => memberships.reload()} />
                    ) : null}
                  </Td>
                </Tr>
              ))}
            </tbody>
          </TableWrap>
        )}
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-zinc-100">Recent expenses paid</h2>
        {(paid.loading ? <Spinner /> : paid.error ? (
          <ErrorNote message={paid.error} onRetry={paid.reload} />
        ) : paid.data!.length === 0 ? (
          <EmptyState message="No expenses." />
        ) : (
          <TableWrap>
            <thead>
              <tr><Th>Description</Th><Th>Crib</Th><Th className="text-right">Amount</Th><Th>Date</Th><Th>Status</Th></tr>
            </thead>
            <tbody>
              {paid.data!.map((e) => (
                <Tr key={e.id}>
                  <Td>{e.description}</Td>
                  <Td className="text-zinc-400">{e.crib?.name}</Td>
                  <Td className="text-right">{formatMoney(e.total_minor, e.currency)}</Td>
                  <Td className="text-zinc-400">{formatDate(e.occurred_on)}</Td>
                  <Td>
                    <span className="flex gap-1">
                      {e.disputed_at && <Badge tone="red">disputed</Badge>}
                      {e.unpaid && <Badge tone="amber">unpaid</Badge>}
                    </span>
                  </Td>
                </Tr>
              ))}
            </tbody>
          </TableWrap>
        ))}
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-zinc-100">Recent settlements</h2>
        {(settlements.loading ? <Spinner /> : settlements.error ? (
          <ErrorNote message={settlements.error} onRetry={settlements.reload} />
        ) : settlements.data!.length === 0 ? (
          <EmptyState message="No settlements." />
        ) : (
          <TableWrap>
            <thead>
              <tr><Th>Crib</Th><Th className="text-right">Amount</Th><Th>Status</Th><Th>Created</Th></tr>
            </thead>
            <tbody>
              {settlements.data!.map((x) => (
                <Tr key={x.id}>
                  <Td className="text-zinc-400">{x.crib?.name}</Td>
                  <Td className="text-right">{formatMoney(x.amount_minor, x.currency)}</Td>
                  <Td><SettlementBadge status={x.status} /></Td>
                  <Td className="text-zinc-400">{formatDateTime(x.created_at)}</Td>
                </Tr>
              ))}
            </tbody>
          </TableWrap>
        ))}
      </section>

      <ConfirmDialog
        open={suspendOpen}
        title={`Suspend ${u.display_name}?`}
        body="A suspended user is locked out of the app: their profile reads and all membership reads are denied by RLS. This does not delete any data and can be reversed."
        confirmLabel="Suspend user"
        danger
        requireReason
        onConfirm={doSuspend}
        onCancel={() => setSuspendOpen(false)}
      />
      <ConfirmDialog
        open={unsuspendOpen}
        title={`Unsuspend ${u.display_name}?`}
        body="The user regains full normal access to the app."
        confirmLabel="Unsuspend"
        onConfirm={async (reason) => {
          await rpc("admin_set_user_suspension", {
            p_target_user_id: u.id,
            p_suspended: false,
            p_reason: reason,
          });
          user.reload();
          memberships.reload();
        }}
        onCancel={() => setUnsuspendOpen(false)}
      />
    </>
  );
}

function RemoveMemberButton({
  cribId, cribName, userId, userName, onDone,
}: {
  cribId: string;
  cribName: string;
  userId: string;
  userName: string;
  onDone: () => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)} className="text-xs text-rose-300 hover:underline">
        remove
      </button>
      <ConfirmDialog
        open={open}
        title={`Remove ${userName} from ${cribName}?`}
        body="The membership is soft-ended: history is kept and the balances of the past are untouched, but the user loses write access to the crib immediately."
        confirmLabel="Remove member"
        danger
        onConfirm={async (reason) => {
          await rpc("admin_remove_crib_member", {
            p_crib_id: cribId,
            p_user_id: userId,
            p_reason: reason,
          });
          onDone();
        }}
        onCancel={() => setOpen(false)}
      />
    </>
  );
}

export function SettlementBadge({ status }: { status: Settlement["status"] }) {
  const tone =
    status === "confirmed" ? "green" :
    status === "pending" ? "amber" :
    status === "cancelled" ? "gray" : "blue";
  return <Badge tone={tone}>{status}</Badge>;
}
