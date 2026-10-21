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

Deno.serve(async (request) => {
  // The function is invoked by a scheduler with the project's secret key.
  const isServiceRole = request.headers.get('apikey') === Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const isScheduler = dispatchSecret != null && request.headers.get('x-dispatch-secret') === dispatchSecret
  if (!isServiceRole && !isScheduler) {
    return json({ error: 'Unauthorized' }, 401)
  }
  if (!serviceAccountJson) return json({ error: 'FIREBASE_SERVICE_ACCOUNT_JSON is not configured' }, 500)

  const serviceAccount = JSON.parse(serviceAccountJson) as { project_id: string }
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // The scheduler can retry safely; due reminders are idempotent per schedule/date.
  const due = await admin.rpc('process_push_due_reminders')
  if (due.error) return json({ error: due.error.message }, 500)
  const claimed = await admin.rpc('claim_push_notification_jobs', { batch_size: 100 })
  if (claimed.error) return json({ error: claimed.error.message }, 500)

  const auth = new GoogleAuth({
    credentials: JSON.parse(serviceAccountJson),
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const client = await auth.getClient()
  let delivered = 0
  for (const job of (claimed.data ?? []) as Job[]) {
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
              android: { priority: 'high' },
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
  return json({ claimed: claimed.data?.length ?? 0, delivered })
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
