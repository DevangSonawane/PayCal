import { withSupabase } from 'npm:@supabase/server'

const json = (body: Record<string, unknown>, status = 200) =>
  Response.json(body, { status })

Deno.serve(
  withSupabase({ auth: 'user' }, async (_request, context) => {
    const claims = context.userClaims as { sub?: string; id?: string } | undefined
    const userId = claims?.sub ?? claims?.id
    if (!userId) return json({ error: 'Authentication required.' }, 401)

    const admin = context.supabaseAdmin

    // The cribs the member is still in.
    //
    // A member that only takes part in a crib can leave it on their own, so
    // the account goes: the membership is closed and the history of the
    // member stays where it is.
    //
    // A member that owns a crib cannot leave it, because a crib must never
    // end up without an owner. That crib has to be handed over or deleted
    // first, and the refusal says which cribs are in the way.
    const { data: memberships, error: membershipReadError } = await admin
      .from('crib_members')
      .select('crib_id')
      .eq('user_id', userId)
      .is('left_at', null)
    if (membershipReadError) {
      return json({ error: 'Could not read the memberships.' }, 500)
    }

    const cribIds = (memberships ?? []).map((membership) => membership.crib_id as string)
    const ownedCribs: { id: string; name: string }[] = []
    const joinedCribs: { id: string; name: string }[] = []
    if (cribIds.length > 0) {
      const { data: cribs, error: cribError } = await admin
        .from('cribs')
        .select('id, name, owner_id')
        .in('id', cribIds)
        .is('deleted_at', null)
      if (cribError) {
        return json({ error: 'Could not verify the cribs.' }, 500)
      }
      for (const crib of cribs ?? []) {
        const entry = {
          id: crib.id as string,
          name: (crib.name as string) || 'Crib',
        }
        if (crib.owner_id === userId) ownedCribs.push(entry)
        else joinedCribs.push(entry)
      }
    }

    if (ownedCribs.length > 0) {
      return json(
        {
          error: 'Hand over or delete the cribs you own before deleting your account.',
          blocked: ownedCribs,
        },
        409,
      )
    }

    const now = new Date().toISOString()
    const { error: invitationError } = await admin
      .from('invitations')
      .update({ revoked_at: now })
      .eq('created_by', userId)
      .is('revoked_at', null)
    if (invitationError) return json({ error: 'Could not revoke invitations.' }, 500)

    const { error: membershipError } = await admin
      .from('crib_members')
      .update({ left_at: now })
      .eq('user_id', userId)
      .is('left_at', null)
    if (membershipError) return json({ error: 'Could not close memberships.' }, 500)

    const { error: profileError } = await admin
      .from('profiles')
      .update({ display_name: 'Removed member', deleted_at: now })
      .eq('id', userId)
    if (profileError) return json({ error: 'Could not anonymise the profile.' }, 500)

    // Financial records still reference public.profiles.id, so that profile is
    // deliberately retained as the anonymised historical identity. The
    // profiles → auth.users foreign key is removed by migration so deleting
    // the Auth identity cannot cascade into shared financial records.
    const { error: deleteUserError } = await admin.auth.admin.deleteUser(userId)
    if (deleteUserError) {
      return json({ error: 'Could not permanently delete the account.' }, 500)
    }

    return json({
      deleted: true,
      left: joinedCribs.map((crib) => crib.name),
    })
  }),
)
