import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const url = new URL(req.url)
  const path = url.pathname.replace(/\/+$/, '')

  // Create Supabase Admin client
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const adminClient = createClient(supabaseUrl, supabaseServiceKey)

  // Fetch Razorpay credentials
  const razorpayKeyId = Deno.env.get('RAZORPAY_KEY_ID') ?? ''
  const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET') ?? ''

  // 1. Endpoint: Create Payment Link
  if (path.endsWith('/create-link')) {
    try {
      // Authenticate the user calling the function
      const authHeader = req.headers.get('Authorization') ?? ''
      if (!authHeader) {
        return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const token = authHeader.replace('Bearer ', '')
      const { data: { user }, error: authError } = await adminClient.auth.getUser(token)

      if (authError || !user) {
        return new Response(JSON.stringify({ error: 'Invalid user token' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const { planType } = await req.json()
      if (planType !== 'monthly' && planType !== 'yearly') {
        return new Response(JSON.stringify({ error: 'Invalid plan type' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const amount = planType === 'monthly' ? 9900 : 99900 // Amount in paise (99 INR or 999 INR)
      const description = planType === 'monthly' ? 'EditFlow Premium - Monthly Plan' : 'EditFlow Premium - Yearly Plan'

      // Call Razorpay API to create Payment Link
      const credentials = btoa(`${razorpayKeyId}:${razorpayKeySecret}`)
      const response = await fetch('https://api.razorpay.com/v1/payment_links', {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${credentials}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          amount: amount,
          currency: 'INR',
          accept_partial: false,
          description: description,
          customer: {
            name: user.userMetadata?.full_name ?? 'EditFlow User',
            email: user.email,
          },
          notify: {
            sms: false,
            email: true,
          },
          reminder_enable: false,
          notes: {
            userId: user.id,
            planType: planType,
          },
          callback_url: 'https://editflow.acsoft.online/app/#/dashboard?payment=success',
          callback_method: 'get',
        }),
      })

      const responseData = await response.json()

      if (!response.ok) {
        console.error('Razorpay Error Response:', responseData)
        return new Response(JSON.stringify({ error: responseData.error?.description ?? 'Failed to create payment' }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      return new Response(JSON.stringify({ short_url: responseData.short_url }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    } catch (e) {
      console.error('Create Link Error:', e)
      return new Response(JSON.stringify({ error: e.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
  }

  // 2. Endpoint: Webhook Listener
  if (path.endsWith('/webhook')) {
    try {
      const payload = await req.json()
      const event = payload.event

      console.log(`Received Razorpay webhook event: ${event}`)

      // Listen for payment_link.paid event
      if (event === 'payment_link.paid') {
        const entity = payload.payload.payment_link.entity
        const notes = entity.notes
        
        const userId = notes.userId
        const planType = notes.planType
        const paymentId = payload.payload.payment.entity.id

        if (!userId || !planType) {
          console.error('Missing userId or planType in payment notes:', notes)
          return new Response('Missing metadata', { status: 400 })
        }

        console.log(`Processing premium upgrade for User: ${userId}, Plan: ${planType}, Payment ID: ${paymentId}`)

        // 1. Insert/Update row in premium_upgrade_requests
        const { error: requestError } = await adminClient
          .from('premium_upgrade_requests')
          .insert({
            user_id: userId,
            plan_type: planType,
            utr: paymentId,
            status: 'approved',
          })

        if (requestError) {
          console.warn('Upgrade request insert error (might already exist):', requestError)
        }

        // 2. Update user profile to premium
        const days = planType === 'yearly' ? 365 : 30
        const expiryDate = new Date()
        expiryDate.setDate(expiryDate.getDate() + days)

        const { error: profileError } = await adminClient
          .from('profiles')
          .update({
            is_premium: true,
            premium_until: expiryDate.toISOString(),
          })
          .eq('id', userId)

        if (profileError) {
          console.error('Failed to update user profile status:', profileError)
          return new Response('Database update failed', { status: 500 })
        }

        console.log(`User ${userId} successfully upgraded to Premium until ${expiryDate.toISOString()}`)
      }

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    } catch (e) {
      console.error('Webhook processing error:', e)
      return new Response(JSON.stringify({ error: e.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  }

  return new Response('Not Found', { status: 404 })
})
