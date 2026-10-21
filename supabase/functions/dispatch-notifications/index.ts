import 'jsr:@supabase/functions-js/edge-runtime.d.ts'

import { createClient } from 'npm:@supabase/supabase-js@2'
import { GoogleAuth } from 'npm:google-auth-library@9'

type Job = {
  id: string
  recipient_id: string
  title: string
  body: string
  data: Record<string, string>
}

const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
const dispatchSecret = Deno.env.get('NOTIFICATION_DISPATCH_SECRET')

function json(message: unknown, status = 200) {
  return new Response(JSON.stringify(message), {
    status,
    headers: { 'content-type': 'application/json' },
  })
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get('authorization')
  if (!header) return null
  const match = /^Bearer\s+(.+)$/i.exec(header.trim())
  return match ? match[1].trim() : null
}

// The role a token carries, read from the token itself. The project secret
// key is not always a JWT, so the role is only checked when it can be read.
function tokenRole(token: string | null): string | null {
  if (!token) return null
  const parts = token.split('.')
  if (parts.length !== 3) return null
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))
    return typeof payload.role === 'string' ? payload.role : null
  } catch {
    return null
  }
}

Deno.serve(async (request) => {
  // The scheduler sweeps the whole outbox with the project's secret key.
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const requestKey = request.headers.get('apikey')
  const token = bearerToken(request)
  const isServiceRole =
    (serviceKey != null && (requestKey === serviceKey || token === serviceKey)) ||
    tokenRole(token) === 'service_role' ||
    tokenRole(requestKey) === 'service_role'
  const isScheduler = dispatchSecret != null && request.headers.get('x-dispatch-secret') === dispatchSecret
  // A signed-in member may ask for their own notifications to be delivered
  // right away. The sweep stays with the scheduler, so a member can never
  // trigger the delivery of somebody else's notifications.
  const isMember = !isServiceRole && !isScheduler
  if (!isServiceRole && !isScheduler && !bearerToken(request)) {
    return json({ error: 'Unauthorized' }, 401)
  }
  if (!serviceAccountJson) return json({ error: 'FIREBASE_SERVICE_ACCOUNT_JSON is not configured' }, 500)

  const serviceAccount = JSON.parse(serviceAccountJson) as { project_id: string }
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  let claimed: { data: unknown; error: { message: string } | null }
  if (isMember) {
    // A member's device asks for the transactional notifications to go out
    // now. The member's access token proves they are signed in; the outbox
    // rows claimed here are the transactional ones, so a recurring reminder
    // keeps the pace of the scheduler.
    const token = bearerToken(request)!
    const user = await admin.auth.getUser(token)
    if (user.error || !user.data?.user) {
      return json({ error: 'Unauthorized' }, 401)
    }
    // The claim runs as the member, so the database knows who asked for it.
    const asMember = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    )
    claimed = await asMember.rpc('claim_push_transactional_jobs', { batch_size: 100 })
  } else {
    // The scheduler can retry safely; due reminders are idempotent per schedule/date.
    const due = await admin.rpc('process_push_due_reminders')
    if (due.error) return json({ error: due.error.message }, 500)
    claimed = await admin.rpc('claim_push_notification_jobs', { batch_size: 100 })
  }
  if (claimed.error) return json({ error: claimed.error.message }, 500)

  const auth = new GoogleAuth({
    credentials: JSON.parse(serviceAccountJson),
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const client = await auth.getClient()
  let delivered = 0
  const jobs = (claimed.data ?? []) as Job[]
  for (const job of jobs) {
    const devices = await admin
      .from('push_devices')
      .select('id, token, platform')
      .eq('user_id', job.recipient_id).eq('enabled', true)
    if (devices.error) {
      await mark(admin, job.id, 'failed', devices.error.message)
      continue
    }
    let error: string | undefined
    for (const device of devices.data ?? []) {
      try {
        await client.request({
          url: `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
          method: 'POST',
          data: {
            message: {
              token: device.token,
              notification: { title: job.title, body: job.body },
              data: Object.fromEntries(
                Object.entries(job.data ?? {}).map(([key, value]) => [key, String(value)]),
              ),
              android: { priority: 'high', notification: { channel_id: 'paycal_reminders' } },
              apns: { payload: { aps: { sound: 'default' } } },
            },
          },
        })
        delivered++
      } catch (exception) {
        error = exception instanceof Error ? exception.message : 'FCM delivery failed'
        if (error.includes('404') || error.includes('UNREGISTERED')) {
          await admin.from('push_devices').delete().eq('id', device.id)
        }
      }
    }
    await mark(admin, job.id, error ? 'failed' : 'delivered', error)
  }
  return json({ claimed: jobs.length, delivered })
})

async function mark(
  admin: ReturnType<typeof createClient>,
  id: string,
  status: 'failed' | 'delivered',
  error?: string,
) {
  const update = status === 'delivered'
    ? { status, delivered_at: new Date().toISOString(), last_error: null }
    : { status, last_error: error ?? 'Unknown delivery error', available_at: new Date(Date.now() + 60_000).toISOString() }
  await admin.from('notification_outbox').update(update).eq('id', id)
}
