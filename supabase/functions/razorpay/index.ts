import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

function getEmailWrapper(title: string, badgeText: string, isSuccess: boolean, innerHtml: string) {
  const badgeBg = isSuccess ? 'rgba(16, 185, 129, 0.1)' : 'rgba(239, 68, 68, 0.1)';
  const badgeTextColor = isSuccess ? '#10B981' : '#EF4444';
  const headerBorderColor = isSuccess ? '#10B981' : '#EF4444';

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${title}</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          background-color: #090D16;
          color: #9CA3AF;
          margin: 0;
          padding: 20px 12px;
          -webkit-font-smoothing: antialiased;
        }
        .wrapper {
          max-width: 700px;
          margin: 0 auto;
          background-color: #111827;
          border: 1px solid #1F2937;
          border-top: 5px solid ${headerBorderColor};
          border-radius: 12px;
          overflow: hidden;
          box-shadow: 0 20px 40px -10px rgba(0, 0, 0, 0.5);
        }
        .header {
          padding: 20px 24px 12px 24px;
          text-align: center;
          background: radial-gradient(circle at top, rgba(13, 148, 136, 0.05) 0%, rgba(17, 24, 39, 0) 70%);
          border-bottom: 1px solid #1F2937;
        }
        .badge {
          display: inline-block;
          background-color: ${badgeBg};
          color: ${badgeTextColor};
          font-size: 10px;
          font-weight: 700;
          letter-spacing: 0.8px;
          padding: 3px 10px;
          border-radius: 99px;
          text-transform: uppercase;
          margin-bottom: 12px;
          border: 1px solid ${isSuccess ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)'};
        }
        .title {
          color: #FFFFFF;
          font-size: 19px;
          font-weight: 800;
          margin: 0;
          line-height: 1.25;
          letter-spacing: -0.4px;
        }
        .body {
          padding: 16px 24px 20px 24px;
          font-size: 13px;
          line-height: 1.5;
          color: #9CA3AF;
        }
        .body p {
          margin: 0 0 10px 0;
        }
        .footer {
          background-color: #0B0F19;
          padding: 18px 24px;
          text-align: center;
          font-size: 10.5px;
          color: #6B7280;
          border-top: 1px solid #1F2937;
        }
        .footer-link {
          color: #10B981;
          text-decoration: none;
          font-weight: 600;
        }
        .highlight {
          color: #FFFFFF;
          font-weight: 600;
        }
        .btn-container {
          text-align: center;
          margin: 16px 0;
        }
        .btn {
          display: inline-block;
          background: linear-gradient(135deg, #0D9488 0%, #10B981 100%);
          color: #ffffff !important;
          font-size: 12px;
          font-weight: 600;
          text-decoration: none;
          padding: 9px 22px;
          border-radius: 8px;
          box-shadow: 0 4px 10px rgba(13, 148, 136, 0.15);
        }
        .info-card {
          background-color: #1F2937;
          border: 1px solid #374151;
          border-radius: 8px;
          padding: 12px 16px;
          margin: 16px 0;
        }
        .info-table {
          width: 100%;
          border-collapse: collapse;
        }
        .info-table td {
          padding: 6px 0;
          font-size: 12px;
          vertical-align: middle;
        }
        .info-table tr:not(:last-child) td {
          border-bottom: 1px solid #374151;
        }
        .label {
          color: #9CA3AF;
          font-weight: 500;
          text-align: left;
        }
        .value {
          color: #FFFFFF;
          font-weight: 600;
          text-align: right;
          word-break: break-all;
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="header">
          <div style="margin-bottom: 12px;">
            <img src="https://editflow.acsoft.online/logo.svg" width="48" height="48" alt="EditFlow Logo" style="display: block; margin: 0 auto; filter: drop-shadow(0 4px 8px rgba(13, 148, 136, 0.2)); border-radius: 14px;" />
          </div>
          <span class="badge">${badgeText}</span>
          <h1 class="title">${title}</h1>
        </div>
        <div class="body">
          ${innerHtml}
        </div>
        <div class="footer">
          <p style="margin: 0 0 6px 0; font-weight: 700; color: #FFFFFF; font-size: 12px;">EditFlow Billing Support</p>
          <p style="margin: 0 0 14px 0; font-size: 10.5px; line-height: 1.5; color: #6B7280;">If you have any questions or did not authorize this action, please reach out to our team at <a href="mailto:supportbyeditflow@acsoft.online" class="footer-link">supportbyeditflow@acsoft.online</a></p>
          <p style="margin: 0; font-size: 10px; color: #4B5563;">&copy; ${new Date().getFullYear()} EditFlow. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
  `;
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
            email: false,
          },
          reminder_enable: false,
          notes: {
            userId: user.id,
            planType: planType,
          },
          callback_url: 'https://editflow.acsoft.online/success.html',
          callback_method: 'get',
        }),
      })

      if (response.status !== 200 && response.status !== 201) {
        const errBody = await response.text()
        console.error('Razorpay API error response:', response.status, errBody)
        return new Response(JSON.stringify({ error: `Razorpay API error: ${errBody}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const linkData = await response.json()
      return new Response(JSON.stringify({ short_url: linkData.short_url }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    } catch (e) {
      console.error('Error creating payment link:', e)
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
            premium_plan_type: planType,
          })
          .eq('id', userId)

        if (profileError) {
          console.error('Failed to update user profile status:', profileError)
          return new Response('Database update failed', { status: 500 })
        }

        console.log(`User ${userId} successfully upgraded to Premium until ${expiryDate.toISOString()}`)

        // 3. Send welcome email via Resend
        const resendApiKey = Deno.env.get('RESEND_API_KEY') || ''
        const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') || 'supportbyeditflow@acsoft.online'

        // Fetch User Profile details to guarantee profile email resolution
        const { data: userProfile, error: profileGetErr } = await adminClient
          .from('profiles')
          .select('email, full_name')
          .eq('id', userId)
          .single();

        if (!profileGetErr && userProfile) {
          const profileEmail = userProfile.email || ''
          const profileName = userProfile.full_name || 'Valued User'

          console.log(`[Resend Email Webhook] resendApiKey exists: ${!!resendApiKey}, fromEmail: ${fromEmail}, targetEmail: ${profileEmail}`);

          if (resendApiKey && profileEmail) {
            try {
              const innerHtml = `
                <p>Hi <span class="highlight">${profileName}</span>,</p>
                <p>Great news! Your payment via Razorpay has been processed successfully, and your account has been upgraded to <strong class="highlight">EditFlow Premium</strong>.</p>
                
                <div class="info-card">
                  <table class="info-table">
                    <tr>
                      <td class="label">Invoice Recipient</td>
                      <td class="value">${profileName} (${profileEmail})</td>
                    </tr>
                    <tr>
                      <td class="label">Invoice Number</td>
                      <td class="value">INV-${new Date().getFullYear()}-${paymentId.substring(0, 6).toUpperCase()}</td>
                    </tr>
                    <tr>
                      <td class="label">Premium Plan Type</td>
                      <td class="value" style="color: #10B981; font-weight: 700;">${planType === 'yearly' ? 'Yearly Premium' : 'Monthly Premium'}</td>
                    </tr>
                    <tr>
                      <td class="label">Transaction Reference</td>
                      <td class="value" style="font-family: monospace;">${paymentId}</td>
                    </tr>
                    <tr>
                      <td class="label">Total Amount Paid</td>
                      <td class="value" style="color: #10B981; font-size: 16px; font-weight: 800;">${planType === 'yearly' ? '₹999' : '₹99'}</td>
                    </tr>
                    <tr>
                      <td class="label">Subscription Active Until</td>
                      <td class="value">${expiryDate.toISOString().split('T')[0]}</td>
                    </tr>
                  </table>
                </div>

                <p>All active limits on creating projects and adding client profiles have been unlocked on your account. Log back into the app to start using your premium tools!</p>
                <div class="btn-container">
                  <a href="https://editflow.acsoft.online/app/" class="btn" style="color: #ffffff;">Access Premium Dashboard</a>
                </div>
              `;
              const htmlContent = getEmailWrapper(
                "Your Premium Access is Active!",
                "Payment Success",
                true,
                innerHtml
              );

              const res = await fetch('https://api.resend.com/emails', {
                method: 'POST',
                headers: {
                  'Authorization': `Bearer ${resendApiKey}`,
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                  from: `EditFlow <${fromEmail}>`,
                  to: profileEmail,
                  subject: 'Your Premium Access is Active! - EditFlow',
                  html: htmlContent,
                }),
              });

              const resData = await res.json();
              console.log(`[Resend Email Webhook] Resend API Response:`, JSON.stringify(resData));
            } catch (emailErr) {
              console.error('Failed to send Resend email:', emailErr);
            }
          }
        }
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
