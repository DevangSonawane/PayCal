export interface Profile {
  id: string;
  display_name: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  suspended_at: string | null;
  suspension_reason: string | null;
  is_admin: boolean;
}

export interface Crib {
  id: string;
  name: string;
  currency: string;
  categories: string[];
  owner_id: string;
  version: number;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  owner?: { display_name: string } | null;
}

export interface CribMember {
  crib_id: string;
  user_id: string;
  joined_at: string;
  left_at: string | null;
  profile?: { display_name: string } | null;
}

export interface Expense {
  id: string;
  crib_id: string;
  description: string;
  total_minor: number;
  currency: string;
  payer_id: string;
  created_by: string;
  category: string;
  occurred_on: string;
  disputed_at: string | null;
  unpaid: boolean;
  version: number;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  payer?: { display_name: string } | null;
  crib?: { name: string; currency: string } | null;
  shares?: { user_id: string; share_minor: number; profile?: { display_name: string } | null } [];
}

export interface Share {
  user_id: string;
  share_minor: number;
  profile?: { display_name: string } | null;
}

export interface Settlement {
  id: string;
  crib_id: string;
  currency: string;
  from_user_id: string;
  to_user_id: string;
  amount_minor: number;
  status: "pending" | "confirmed" | "cancelled" | "self_managed";
  idempotency_key: string;
  version: number;
  created_at: string;
  updated_at: string;
  from_user?: { display_name: string } | null;
  to_user?: { display_name: string } | null;
  crib?: { name: string; currency: string } | null;
}

export interface Invitation {
  id: string;
  crib_id: string;
  token_hash: string;
  created_by: string;
  created_at: string;
  expires_at: string;
  revoked_at: string | null;
  accepted_by: string | null;
  accepted_at: string | null;
}

export interface RecurringSchedule {
  id: string;
  crib_id: string;
  description: string;
  amount_minor: number;
  currency: string;
  category: string;
  frequency: "monthly" | "yearly";
  recipient_id: string;
  created_by: string;
  payer_id: string | null;
  resume_from: string | null;
  local_hour: number;
  local_minute: number;
  anchor_day: number;
  time_zone: string;
  start_date: string;
  active: boolean;
  created_at: string;
  updated_at: string;
  payer?: { display_name: string } | null;
  recipient?: { display_name: string } | null;
  crib?: { name: string; currency: string } | null;
}

export interface ActivityEvent {
  id: number;
  crib_id: string;
  actor_id: string | null;
  action: string;
  target_id: string | null;
  request_id: string | null;
  metadata: Record<string, unknown>;
  occurred_at: string;
  crib?: { name: string } | null;
  actor?: { display_name: string } | null;
}

export interface AuditLogRow {
  id: number;
  admin_id: string;
  action: string;
  target_type: string;
  target_id: string | null;
  reason: string | null;
  details: Record<string, unknown>;
  created_at: string;
  admin?: { display_name: string } | null;
}

export interface DashboardStats {
  profiles_total: number;
  profiles_suspended: number;
  profiles_deleted: number;
  cribs_live: number;
  cribs_deleted: number;
  members_active: number;
  members_departed: number;
  expenses_total: number;
  expenses_last_30d: number;
  disputed_open: number;
  expenses_unpaid: number;
  settlements_confirmed: number;
  schedules_active: number;
  schedules_paused: number;
  schedules_cancelled: number;
  invitations_open: number;
  outbox_pending: number;
  expenses_per_day: { day: string; count: number; total_minor: number }[];
  currency_totals: { currency: string; expenses_minor: number; settlements_minor: number }[];
}
