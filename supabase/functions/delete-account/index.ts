import { withSupabase } from 'npm:@supabase/server'

const json = (body: Record<string, unknown>, status = 200) =>
  Response.json(body, { status })

Deno.serve(
  withSupabase({ auth: 'user' }, async (_request, context) => {
    const claims = context.userClaims as { sub?: string; id?: string } | undefined
    const userId = claims?.sub ?? claims?.id
    if (!userId) return json({ error: 'Authentication required.' }, 401)

    const admin = context.supabaseAdmin
    const { data: ownedCribs, error: ownerError } = await admin
      .from('cribs')
      .select('id')
      .eq('owner_id', userId)
      .is('deleted_at', null)
      .limit(1)
    if (ownerError) return json({ error: 'Could not verify crib ownership.' }, 500)
    if ((ownedCribs?.length ?? 0) > 0) {
      return json(
        { error: 'Transfer ownership of every active crib before deleting your account.' },
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

    const { error: signOutError } = await admin.auth.admin.signOut(userId, 'global')
    if (signOutError) return json({ error: 'Could not revoke sessions.' }, 500)

    // Keep auth.users and public.profiles intact: financial rows reference the
    // profile. An indefinite ban prevents reauthentication pending the product
    // and legal retention decisions documented in ACCOUNT_DELETION.md.
    const { error: banError } = await admin.auth.admin.updateUserById(userId, {
      ban_duration: '876000h',
    })
    if (banError) return json({ error: 'Could not deactivate the account.' }, 500)

    return json({ deleted: true })
  }),
)
