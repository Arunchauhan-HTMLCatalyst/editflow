import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight options request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Extract Authorization JWT header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Create normal client with user's JWT to verify admin privileges
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    // Get current user details from auth.users
    const { data: { user }, error: userError } = await userClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid user token: ' + userError?.message }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Query profiles to check role & suspension status
    const { data: profile, error: profileError } = await userClient
      .from('profiles')
      .select('role, is_suspended')
      .eq('id', user.id)
      .maybeSingle()

    if (profileError || !profile || profile.role !== 'admin' || profile.is_suspended) {
      return new Response(JSON.stringify({ error: 'Forbidden: Insufficient administrative privileges' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 3. Create admin client using the service role key to bypass RLS
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const adminClient = createClient(supabaseUrl, supabaseServiceKey)

    // 4. Parse request body
    const body = await req.json()
    const { action, payload } = body

    // 5. Route based on action
    switch (action) {
      case 'get_stats': {
        const thirtyDaysAgo = new Date()
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

        const oneDayAgo = new Date()
        oneDayAgo.setDate(oneDayAgo.getDate() - 1)

        const fourteenDaysAgo = new Date()
        fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14)

        const [
          { count: userCount },
          { count: activeUsersCount },
          { count: projectCount },
          { count: clientCount },
          { count: reviewCount },
          { count: commentCount },
          { count: newUsersCount },
          { data: recentActivitiesForDAU },
          { data: recentActivitiesForMAU },
          { data: recentProfiles },
        ] = await Promise.all([
          adminClient.from('profiles').select('*', { count: 'exact', head: true }),
          adminClient.from('profiles').select('*', { count: 'exact', head: true }).eq('is_suspended', false),
          adminClient.from('projects').select('*', { count: 'exact', head: true }),
          adminClient.from('clients').select('*', { count: 'exact', head: true }),
          adminClient.from('reviews').select('*', { count: 'exact', head: true }),
          adminClient.from('comments').select('*', { count: 'exact', head: true }),
          adminClient.from('profiles').select('*', { count: 'exact', head: true }).gte('created_at', thirtyDaysAgo.toISOString()),
          adminClient.from('activities').select('user_id').gte('created_at', oneDayAgo.toISOString()),
          adminClient.from('activities').select('user_id').gte('created_at', thirtyDaysAgo.toISOString()),
          adminClient.from('profiles').select('id, full_name, email, created_at').order('created_at', { ascending: false }).limit(20),
        ])

        const uniqueDAU = new Set((recentActivitiesForDAU || []).map((a: any) => a.user_id)).size
        const uniqueMAU = new Set((recentActivitiesForMAU || []).map((a: any) => a.user_id)).size

        const recentNewUsersList = recentProfiles || []

        // Calculate Storage Used
        let totalStorageBytes = 0
        const { data: buckets } = await adminClient.storage.listBuckets()
        const targetBuckets = buckets?.map(b => b.name) || ['video-reviews', 'voice-comments']
        
        for (const bucketName of targetBuckets) {
          const { data: files } = await adminClient.storage.from(bucketName).list()
          if (files) {
            totalStorageBytes += files.reduce((sum, f) => sum + (f.metadata?.size || 0), 0)
          }
        }

        // Fetch Postgres Database Size (tables, metadata, indexes)
        let dbSize = 0
        try {
          const { data: dbData } = await adminClient.rpc('get_database_size')
          if (dbData) {
            dbSize = Number(dbData)
          }
        } catch (e) {
          console.error('Error fetching database size:', e)
        }

        // Recent activity
        const { data: recentActivity } = await adminClient
          .from('activities')
          .select('*')
          .eq('type', 'admin_log')
          .order('created_at', { ascending: false })
          .limit(15)

        // Support tickets/requests
        const { data: supportRequests, error: supportError } = await adminClient
          .from('support_tickets')
          .select('*, profiles(full_name, email)')
          .order('created_at', { ascending: false })

        if (supportError) {
          throw new Error('Support query error: ' + supportError.message);
        }

        // Fetch pending premium upgrade requests
        const { data: upgradeRequests, error: upgradeError } = await adminClient
          .from('premium_upgrade_requests')
          .select('*, profiles(full_name, email)')
          .eq('status', 'pending')
          .order('created_at', { ascending: false });

        if (upgradeError) {
          throw new Error('Upgrade requests query error: ' + upgradeError.message);
        }

        return new Response(JSON.stringify({
          stats: {
            totalUsers: userCount || 0,
            activeUsers: activeUsersCount || 0,
            newUsers: newUsersCount || 0,
            totalProjects: projectCount || 0,
            totalClients: clientCount || 0,
            totalReviews: reviewCount || 0,
            totalComments: commentCount || 0,
            totalStorageUsed: totalStorageBytes + dbSize,
            dau: uniqueDAU,
            mau: uniqueMAU,
            dailyNewUsers: recentNewUsersList,
          },
          recentActivity: recentActivity || [],
          supportRequests: supportRequests || [],
          upgradeRequests: upgradeRequests || []
        }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
      }

      case 'get_users': {
        const searchStr = payload?.search || ''
        let query = adminClient
          .from('profiles')
          .select('*')

        if (searchStr) {
          const trimmed = searchStr.trim()
          const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(trimmed)
          if (isUuid) {
            query = query.eq('id', trimmed)
          } else {
            query = query.or(`full_name.ilike.%${trimmed}%,email.ilike.%${trimmed}%`)
          }
        }

        const { data: users, error: fetchErr } = await query.order('created_at', { ascending: false })
        if (fetchErr) throw fetchErr

        // Fetch counts manually to avoid missing foreign key relation cache errors
        const [ { data: projects }, { data: clients } ] = await Promise.all([
          adminClient.from('projects').select('user_id'),
          adminClient.from('clients').select('user_id'),
        ])

        const projectCounts: Record<string, number> = {}
        const clientCounts: Record<string, number> = {}

        for (const p of (projects || [])) {
          projectCounts[p.user_id] = (projectCounts[p.user_id] || 0) + 1
        }
        for (const c of (clients || [])) {
          clientCounts[c.user_id] = (clientCounts[c.user_id] || 0) + 1
        }

        const usersWithCounts = (users || []).map(u => ({
          ...u,
          projects: { count: projectCounts[u.id] || 0 },
          clients: { count: clientCounts[u.id] || 0 },
        }))

        return new Response(JSON.stringify({ users: usersWithCounts }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'user_action': {
        const { targetUserId, userAction, targetRole } = payload
        
        let desc = ''
        if (userAction === 'suspend') {
          const { error } = await adminClient.from('profiles').update({ is_suspended: true }).eq('id', targetUserId)
          if (error) throw error
          desc = `Suspended user account (ID: ${targetUserId})`
        } else if (userAction === 'activate') {
          const { error } = await adminClient.from('profiles').update({ is_suspended: false }).eq('id', targetUserId)
          if (error) throw error
          desc = `Activated user account (ID: ${targetUserId})`
        } else if (userAction === 'change_role') {
          const { error } = await adminClient.from('profiles').update({ role: targetRole }).eq('id', targetUserId)
          if (error) throw error
          desc = `Changed role of user (ID: ${targetUserId}) to ${targetRole}`
        } else if (userAction === 'delete') {
          const { error } = await adminClient.auth.admin.deleteUser(targetUserId)
          if (error) throw error
          desc = `Deleted user account (ID: ${targetUserId})`
        }

        // Insert audit log
        if (desc) {
          await adminClient.from('activities').insert({
            user_id: user?.id,
            type: 'admin_log',
            description: desc,
          })
        }

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'check_expired_subscriptions': {
        const nowStr = new Date().toISOString();

        // Fetch expired premium users
        const { data: expiredUsers, error: fetchErr } = await adminClient
          .from('profiles')
          .select('id, email, full_name, premium_plan_type')
          .eq('is_premium', true)
          .lt('premium_until', nowStr);

        if (fetchErr) throw fetchErr;

        if (expiredUsers && expiredUsers.length > 0) {
          const resendApiKey = Deno.env.get('RESEND_API_KEY');
          const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') || 'supportbyeditflow@acsoft.online';

          for (const user of expiredUsers) {
            // Update profile back to free limits
            await adminClient
              .from('profiles')
              .update({
                is_premium: false,
                premium_plan_type: null,
              })
              .eq('id', user.id);

            // Log activity
            await adminClient.from('activities').insert({
              user_id: user.id,
              type: 'support_response',
              description: 'Your Premium subscription has expired. Limits on clients and projects are active again.',
            });

            // Send notification email
            if (resendApiKey && user.email) {
              try {
                const htmlContent = `
                  <!DOCTYPE html>
                  <html>
                  <head>
                    <meta charset="utf-8">
                    <title>EditFlow Premium Expired</title>
                    <style>
                      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0B0F19; color: #E2E8F0; margin: 0; padding: 40px 20px; }
                      .container { max-width: 600px; margin: 0 auto; background-color: #111827; border: 1px solid #1F2937; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3); }
                      .header { text-align: center; margin-bottom: 30px; }
                      .title { color: #ffffff; font-size: 24px; font-weight: 800; margin: 10px 0; }
                      .badge { display: inline-block; background-color: #EF4444; color: #ffffff; font-size: 11px; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.5px; margin-bottom: 20px; }
                      .content { font-size: 15px; line-height: 1.6; color: #9CA3AF; margin-bottom: 30px; }
                      .highlight { color: #ffffff; font-weight: 600; }
                      .btn { display: inline-block; background-color: #0D9488; color: #ffffff; text-decoration: none; font-size: 14px; font-weight: 700; padding: 12px 24px; border-radius: 8px; text-align: center; margin: 10px 0; }
                      .footer { text-align: center; font-size: 12px; color: #6B7280; border-top: 1px solid #1F2937; padding-top: 20px; }
                    </style>
                  </head>
                  <body>
                    <div class="container">
                      <div class="header">
                        <span class="badge">SUBSCRIPTION ENDED</span>
                        <div class="title">Your Premium Access Has Expired</div>
                      </div>
                      <div class="content">
                        Hi <span class="highlight">${user.full_name || 'there'}</span>,<br><br>
                        Your EditFlow Premium subscription has ended. The limits of the Free plan (maximum of 5 clients and 10 projects) are now active on your account.<br><br>
                        To continue managing unlimited clients and projects without interruptions, please renew your subscription.
                      </div>
                      <div style="text-align: center;">
                        <a href="https://editflow.acsoft.online/app/#/settings" class="btn" style="color: #ffffff;">Renew Premium Now</a>
                      </div>
                      <br>
                      <div class="footer">
                        Sent automatically by EditFlow Core • supportbyeditflow@acsoft.online
                      </div>
                    </div>
                  </body>
                  </html>
                `;

                await fetch('https://api.resend.com/emails', {
                  method: 'POST',
                  headers: {
                    'Authorization': `Bearer ${resendApiKey}`,
                    'Content-Type': 'application/json',
                  },
                  body: JSON.stringify({
                    from: `EditFlow <${fromEmail}>`,
                    to: [user.email],
                    subject: '🚨 Your EditFlow subscription has ended',
                    html: htmlContent,
                  }),
                });
              } catch (emailErr) {
                console.error('Failed to send expiry email notification:', emailErr);
              }
            }
          }
        }

        return new Response(JSON.stringify({ success: true, expiredCount: expiredUsers?.length || 0 }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      case 'get_upgrade_requests': {
        const { data: upgradeRequests, error } = await adminClient
          .from('premium_upgrade_requests')
          .select('*, profiles(full_name, email)')
          .order('created_at', { ascending: false })

        if (error) throw error

        return new Response(JSON.stringify({ upgradeRequests }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'approve_premium_upgrade': {
        const { requestId, duration } = payload;
        if (!requestId || !duration) {
          throw new Error('Missing requestId or duration parameter.');
        }

        // Fetch request details
        const { data: request, error: reqErr } = await adminClient
          .from('premium_upgrade_requests')
          .select('*, profiles(email, full_name)')
          .eq('id', requestId)
          .single();

        if (reqErr) throw reqErr;
        if (request.status !== 'pending') {
          throw new Error('Upgrade request is already processed.');
        }

        // Calculate expiration date
        let expiryDate: Date;
        let planLabel = '';
        if (duration === 'monthly') {
          expiryDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);
          planLabel = 'Monthly (₹99)';
        } else if (duration === 'yearly') {
          expiryDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 365);
          planLabel = 'Yearly (₹999)';
        } else {
          expiryDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 365 * 100);
          planLabel = 'Lifetime / Custom';
        }

        const premiumUntil = expiryDate.toISOString();

        // 1. Update database user profile
        const { error: updateError } = await adminClient
          .from('profiles')
          .update({
            is_premium: true,
            premium_until: premiumUntil,
            premium_started_at: new Date().toISOString(),
            premium_plan_type: duration,
          })
          .eq('id', request.user_id);

        if (updateError) throw updateError;

        // 2. Mark request as approved
        const { error: markApprovedError } = await adminClient
          .from('premium_upgrade_requests')
          .update({
            status: 'approved',
            updated_at: new Date().toISOString(),
          })
          .eq('id', requestId);

        if (markApprovedError) throw markApprovedError;

        // 3. Log the upgrade for the user (Notification Activity)
        await adminClient.from('activities').insert({
          user_id: request.user_id,
          type: 'support_response',
          description: `Congratulations! Your Premium subscription upgrade has been approved. Plan: ${planLabel}. Expiration: ${premiumUntil.split('T')[0]}.`,
        });

        // 4. Send Welcome email
        const resendApiKey = Deno.env.get('RESEND_API_KEY');
        const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') || 'supportbyeditflow@acsoft.online';

        if (resendApiKey && request.profiles?.email) {
          try {
            const htmlContent = `
              <!DOCTYPE html>
              <html>
              <head>
                <meta charset="utf-8">
                <title>EditFlow Premium Active</title>
                <style>
                  body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0B0F19; color: #E2E8F0; margin: 0; padding: 40px 20px; }
                  .container { max-width: 600px; margin: 0 auto; background-color: #111827; border: 1px solid #1F2937; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3); }
                  .header { text-align: center; margin-bottom: 30px; }
                  .title { color: #ffffff; font-size: 24px; font-weight: 800; margin: 10px 0; }
                  .badge { display: inline-block; background-color: #10B981; color: #ffffff; font-size: 11px; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.5px; margin-bottom: 20px; }
                  .content { font-size: 15px; line-height: 1.6; color: #9CA3AF; margin-bottom: 30px; }
                  .highlight { color: #ffffff; font-weight: 600; }
                  .invoice-box { background-color: #1F2937; border: 1px solid #374151; border-radius: 8px; padding: 20px; margin: 24px 0; text-align: left; }
                  .invoice-header { display: flex; justify-content: space-between; border-bottom: 1px solid #374151; padding-bottom: 12px; margin-bottom: 16px; }
                  .footer { text-align: center; font-size: 12px; color: #6B7280; border-top: 1px solid #1F2937; padding-top: 20px; }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="header">
                    <div style="text-align: center; margin-bottom: 20px;">
                      <svg width="60" height="60" viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg" style="margin: 0 auto; display: block;">
                        <rect width="120" height="120" rx="30" fill="url(#grad)" />
                        <defs>
                          <linearGradient id="grad" x1="0" y1="0" x2="120" y2="120" gradientUnits="userSpaceOnUse">
                            <stop stop-color="#0D9488" />
                            <stop offset="1" stop-color="#10B981" />
                          </linearGradient>
                        </defs>
                        <text x="30" y="82" fill="white" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-weight="900" font-size="64" letter-spacing="-4">ef</text>
                      </svg>
                    </div>
                    <span class="badge">PRO UPGRADE APPROVED</span>
                    <div class="title">Your Premium Access is Active!</div>
                  </div>
                  <div class="content">
                    Hi <span class="highlight">${request.profiles.full_name || 'there'}</span>,<br><br>
                    Great news! Your manual payment verification has been completed by our admin team, and your <strong>EditFlow Premium (${duration === 'yearly' ? 'Yearly' : 'Monthly'})</strong> subscription is now active!
                    
                    <div class="invoice-box">
                      <div style="border-bottom: 1px solid #374151; padding-bottom: 12px; margin-bottom: 16px;">
                        <table style="width: 100%;">
                          <tr>
                            <td>
                              <span style="font-size: 10px; color: #9CA3AF; text-transform: uppercase;">Invoice To</span>
                              <div style="font-size: 13px; font-weight: bold; color: #ffffff;">${request.profiles.full_name || 'Valued User'}</div>
                              <div style="font-size: 11px; color: #9CA3AF;">${request.profiles.email}</div>
                            </td>
                            <td style="text-align: right;">
                              <span style="font-size: 10px; color: #9CA3AF; text-transform: uppercase;">Invoice Details</span>
                              <div style="font-size: 12px; font-weight: bold; color: #ffffff;">INV-${new Date().getFullYear()}-${requestId.substring(0, 6).toUpperCase()}</div>
                              <div style="font-size: 11px; color: #9CA3AF;">Date: ${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}</div>
                            </td>
                          </tr>
                        </table>
                      </div>
                      
                      <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
                        <thead>
                          <tr style="border-bottom: 1px solid #374151; text-align: left;">
                            <th style="padding: 8px 0; font-size: 10px; color: #9CA3AF; text-transform: uppercase;">Description</th>
                            <th style="padding: 8px 0; font-size: 10px; color: #9CA3AF; text-transform: uppercase; text-align: right;">Amount</th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            <td style="padding: 12px 0 6px 0; font-size: 13px; color: #E2E8F0; font-weight: bold;">
                              EditFlow Pro Subscription (${duration === 'yearly' ? 'Yearly' : 'Monthly'})
                            </td>
                            <td style="padding: 12px 0 6px 0; font-size: 13px; color: #E2E8F0; font-weight: bold; text-align: right;">
                              ${duration === 'yearly' ? '₹999' : '₹99'}
                            </td>
                          </tr>
                          <tr style="border-bottom: 1px solid #374151;">
                            <td style="padding: 4px 0 12px 0; font-size: 11px; color: #9CA3AF;">
                              UTR Reference: <span style="font-family: monospace; color: #10B981; font-weight: bold;">${request.utr}</span>
                            </td>
                            <td style="padding: 4px 0 12px 0; font-size: 11px; color: #9CA3AF; text-align: right;">
                              Paid
                            </td>
                          </tr>
                          <tr>
                            <td style="padding: 12px 0 0 0; font-size: 13px; color: #ffffff; font-weight: bold;">Total Amount Paid</td>
                            <td style="padding: 12px 0 0 0; font-size: 15px; color: #10B981; font-weight: bold; text-align: right;">
                              ${duration === 'yearly' ? '₹999' : '₹99'}
                            </td>
                          </tr>
                        </tbody>
                      </table>
                      
                      <div style="background-color: rgba(16, 185, 129, 0.08); border: 1px dashed rgba(16, 185, 129, 0.3); border-radius: 6px; padding: 10px; text-align: center; font-size: 11px; color: #10B981; font-weight: bold;">
                        Verification Status: APPROVED & ACTIVATED
                      </div>
                    </div>
                  </div>
                  <div class="footer">
                    Sent automatically by EditFlow Billing Core • supportbyeditflow@acsoft.online
                  </div>
                </div>
              </body>
              </html>
            `;

            await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${resendApiKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                from: `EditFlow <${fromEmail}>`,
                to: [request.profiles.email],
                subject: `🎉 Your EditFlow ${duration === 'yearly' ? 'Yearly' : 'Monthly'} Upgrade Approved!`,
                html: htmlContent,
              }),
            });
          } catch (emailErr) {
            console.error('Failed to send Welcome email:', emailErr);
          }
        }

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      case 'reject_premium_upgrade': {
        const { requestId, feedback } = payload;
        if (!requestId) {
          throw new Error('Missing requestId parameter.');
        }

        // Fetch request details
        const { data: request, error: reqErr } = await adminClient
          .from('premium_upgrade_requests')
          .select('*, profiles(email, full_name)')
          .eq('id', requestId)
          .single();

        if (reqErr) throw reqErr;
        if (request.status !== 'pending') {
          throw new Error('Upgrade request is already processed.');
        }

        // 1. Mark request as rejected
        const { error: markRejectedError } = await adminClient
          .from('premium_upgrade_requests')
          .update({
            status: 'rejected',
            feedback: feedback || 'Invalid UTR reference number or payment not received.',
            updated_at: new Date().toISOString(),
          })
          .eq('id', requestId);

        if (markRejectedError) throw markRejectedError;

        // 2. Log activity
        await adminClient.from('activities').insert({
          user_id: request.user_id,
          type: 'support_response',
          description: `Your ${request.plan_type === 'yearly' ? 'Yearly' : 'Monthly'} Premium Upgrade request has been rejected. Details: ${feedback || 'Invalid transaction UTR reference number or payment not received.'}`,
        });

        // 3. Send email
        const resendApiKey = Deno.env.get('RESEND_API_KEY');
        const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') || 'supportbyeditflow@acsoft.online';

        if (resendApiKey && request.profiles?.email) {
          try {
            const htmlContent = `
              <!DOCTYPE html>
              <html>
              <head>
                <meta charset="utf-8">
                <title>EditFlow Premium Upgrade Rejected</title>
                <style>
                  body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0B0F19; color: #E2E8F0; margin: 0; padding: 40px 20px; }
                  .container { max-width: 600px; margin: 0 auto; background-color: #111827; border: 1px solid #1F2937; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3); }
                  .header { text-align: center; margin-bottom: 30px; }
                  .title { color: #ffffff; font-size: 24px; font-weight: 800; margin: 10px 0; }
                  .badge { display: inline-block; background-color: #EF4444; color: #ffffff; font-size: 11px; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.5px; margin-bottom: 20px; }
                  .content { font-size: 15px; line-height: 1.6; color: #9CA3AF; margin-bottom: 30px; }
                  .highlight { color: #ffffff; font-weight: 600; }
                  .feedback-box { background-color: #1F2937; border-left: 4px solid #EF4444; border-radius: 4px; padding: 16px; margin: 24px 0; color: #E2E8F0; font-size: 14px; }
                  .btn { display: inline-block; background-color: #0D9488; color: #ffffff; text-decoration: none; font-size: 14px; font-weight: 700; padding: 12px 24px; border-radius: 8px; text-align: center; margin: 10px 0; }
                  .footer { text-align: center; font-size: 12px; color: #6B7280; border-top: 1px solid #1F2937; padding-top: 20px; }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="header">
                    <span class="badge">UPGRADE REJECTED</span>
                    <div class="title">Premium Upgrade Request Status</div>
                  </div>
                  <div class="content">
                    Hi <span class="highlight">${request.profiles.full_name || 'there'}</span>,<br><br>
                    We reviewed your manual payment verification request for the <strong>EditFlow Pro ${request.plan_type === 'yearly' ? 'Yearly' : 'Monthly'} Plan</strong>, but we were unable to approve it at this time.<br>
                    This is usually due to an incorrect UTR/Reference number or matching payment not being found in our accounts.
                  </div>
                  <div class="feedback-box">
                    <strong>Reason/Feedback:</strong><br>
                    ${feedback || 'Invalid transaction UTR reference number or payment not received. Please verify and submit request again.'}
                  </div>
                  <div style="text-align: center;">
                    <a href="https://editflow.acsoft.online/app/#/settings" class="btn" style="color: #ffffff;">Try Upgrade Again</a>
                  </div>
                  <br>
                  <div class="footer">
                    Sent automatically by EditFlow Billing Core • supportbyeditflow@acsoft.online
                  </div>
                </div>
              </body>
              </html>
            `;

            await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${resendApiKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                from: `EditFlow <${fromEmail}>`,
                to: [request.profiles.email],
                subject: `🚨 EditFlow Premium Upgrade Rejected`,
                html: htmlContent,
              }),
            });
          } catch (emailErr) {
            console.error('Failed to send rejection email:', emailErr);
          }
        }

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      case 'approve_premium': {
        const { ticketId, targetUserId, duration } = payload;
        if (!ticketId || !targetUserId) {
          throw new Error('Missing ticketId or targetUserId parameter.');
        }

        // Fetch User Profile details to send custom email
        const { data: userProfile, error: profileErr } = await adminClient
          .from('profiles')
          .select('email, full_name')
          .eq('id', targetUserId)
          .single();

        if (profileErr) throw profileErr;

        // Calculate expiration date
        let expiryDate: Date;
        let planLabel = '';
        if (duration === 'monthly') {
          expiryDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);
          planLabel = 'Monthly (₹99)';
        } else if (duration === 'yearly') {
          expiryDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 365);
          planLabel = 'Yearly (₹999)';
        } else {
          expiryDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 365 * 100);
          planLabel = 'Lifetime / Custom';
        }

        const premiumUntil = expiryDate.toISOString();

        // Update database user profile
        const { error: updateError } = await adminClient
          .from('profiles')
          .update({
            is_premium: true,
            premium_until: premiumUntil,
            premium_started_at: new Date().toISOString(),
            premium_plan_type: duration,
          })
          .eq('id', targetUserId);

        if (updateError) throw updateError;

        // Delete the support ticket (resolved)
        const { error: deleteTicketError } = await adminClient
          .from('support_tickets')
          .delete()
          .eq('id', ticketId);

        if (deleteTicketError) throw deleteTicketError;

        // Log the upgrade for the user (Notification Activity)
        await adminClient.from('activities').insert({
          user_id: targetUserId,
          type: 'support_response',
          description: `Congratulations! Your Premium subscription upgrade has been approved. Plan: ${planLabel}. Expiration: ${premiumUntil.split('T')[0]}.`,
        });

        // Send Welcome email
        const resendApiKey = Deno.env.get('RESEND_API_KEY');
        const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') || 'supportbyeditflow@acsoft.online';

        if (resendApiKey && userProfile?.email) {
          try {
            const htmlContent = `
              <!DOCTYPE html>
              <html>
              <head>
                <meta charset="utf-8">
                <title>EditFlow Premium Active</title>
                <style>
                  body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0B0F19; color: #E2E8F0; margin: 0; padding: 40px 20px; }
                  .container { max-width: 600px; margin: 0 auto; background-color: #111827; border: 1px solid #1F2937; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3); }
                  .header { text-align: center; margin-bottom: 30px; }
                  .title { color: #ffffff; font-size: 24px; font-weight: 800; margin: 10px 0; }
                  .badge { display: inline-block; background-color: #10B981; color: #ffffff; font-size: 11px; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.5px; margin-bottom: 20px; }
                  .content { font-size: 15px; line-height: 1.6; color: #9CA3AF; margin-bottom: 30px; }
                  .highlight { color: #ffffff; font-weight: 600; }
                  .info-table { width: 100%; border-collapse: collapse; margin: 24px 0; background-color: #1F2937; border-radius: 8px; overflow: hidden; }
                  .info-table td { padding: 14px 16px; border-bottom: 1px solid #374151; font-size: 13.5px; }
                  .info-table td:first-child { color: #9CA3AF; font-weight: 500; width: 40%; }
                  .info-table td:last-child { color: #FFFFFF; font-weight: 600; text-align: right; }
                  .footer { text-align: center; font-size: 12px; color: #6B7280; border-top: 1px solid #1F2937; padding-top: 20px; }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="header">
                    <span class="badge">PRO UPGRADE SUCCESS</span>
                    <div class="title">Your Premium Access is Active!</div>
                  </div>
                  <div class="content">
                    Hi <span class="highlight">${userProfile.full_name || 'there'}</span>,<br><br>
                    Great news! Your manual payment verification has been completed by our admin team, and your <strong>EditFlow Premium</strong> subscription is now active!
                  </div>
                  <table class="info-table">
                    <tr>
                      <td>Subscription Plan</td>
                      <td>${planLabel}</td>
                    </tr>
                    <tr>
                      <td>Status</td>
                      <td style="color: #10B981;">Active / Unlocked</td>
                    </tr>
                    <tr>
                      <td>Expiration Date</td>
                      <td>${premiumUntil.split('T')[0]}</td>
                    </tr>
                  </table>
                  <div class="content">
                    All limits on adding clients and projects have been completely removed. Log back into your app to enjoy unlimited access!
                  </div>
                  <div class="footer">
                    Sent automatically by EditFlow Core • supportbyeditflow@acsoft.online
                  </div>
                </div>
              </body>
              </html>
            `;

            await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${resendApiKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                from: `EditFlow <${fromEmail}>`,
                to: [userProfile.email],
                subject: '🚀 Welcome to EditFlow Premium!',
                html: htmlContent,
              }),
            });
          } catch (emailErr) {
            console.error('Failed to send Welcome email notification:', emailErr);
          }
        }

        return new Response(JSON.stringify({ success: true, premiumUntil }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      case 'verify_stripe_session': {
        const { sessionId } = payload;
        const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
        if (!stripeKey) {
          throw new Error('STRIPE_SECRET_KEY secret is not configured on Supabase.');
        }

        // Fetch Checkout Session from Stripe
        const sessionRes = await fetch(`https://api.stripe.com/v1/checkout/sessions/${sessionId}`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${stripeKey}`,
          },
        });

        if (!sessionRes.ok) {
          const errText = await sessionRes.text();
          throw new Error(`Stripe Checkout Session API returned error: ${errText}`);
        }

        const session = await sessionRes.json();
        if (session.payment_status !== 'paid' && session.status !== 'complete') {
          throw new Error(`Transaction is unpaid. Status: ${session.payment_status}`);
        }

        // Determine expiration timestamp from subscription (if present)
        let premiumUntil: string | null = null;
        if (session.subscription) {
          const subRes = await fetch(`https://api.stripe.com/v1/subscriptions/${session.subscription}`, {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${stripeKey}`,
            },
          });
          if (subRes.ok) {
            const sub = await subRes.json();
            if (sub.current_period_end) {
              premiumUntil = new Date(sub.current_period_end * 1000).toISOString();
            }
          }
        }

        // If no subscription is linked (e.g. they bought a lifetime option instead),
        // we set premiumUntil to 100 years from now.
        if (!premiumUntil) {
          premiumUntil = new Date(Date.now() + 1000 * 60 * 60 * 24 * 365 * 100).toISOString();
        }

        const targetUserId = session.client_reference_id || user?.id;
        if (!targetUserId) {
          throw new Error('Could not identify user ID associated with checkout session.');
        }

        // Update database user profile
        const { error: updateError } = await adminClient
          .from('profiles')
          .update({
            is_premium: true,
            premium_until: premiumUntil,
          })
          .eq('id', targetUserId);

        if (updateError) throw updateError;

        // Log the upgrade for the user
        await adminClient.from('activities').insert({
          user_id: targetUserId,
          type: 'support_response',
          description: `Congratulations! Your account has been upgraded to Premium until ${premiumUntil.split('T')[0]}.`,
        });

        return new Response(JSON.stringify({ success: true, premiumUntil }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      case 'handle_support_ticket': {
        const { ticketId, action, targetUserId, feedback } = payload
        if (!ticketId) throw new Error('Missing ticketId');

        // Fetch ticket details to see if it is a Premium Upgrade Request
        const { data: ticket } = await adminClient
          .from('support_tickets')
          .select('description')
          .eq('id', ticketId)
          .maybeSingle();

        const ticketDesc = ticket?.description || '';
        const isUpgradeRequest = ticketDesc.includes('[Premium Upgrade Request]');
        const requestedPlan = ticketDesc.includes('Plan: Yearly') ? 'Yearly' : 'Monthly';

        let desc = ''
        if (action === 'accept') {
          if (isUpgradeRequest) {
            desc = `Your ${requestedPlan} Premium Upgrade request has been accepted. ${feedback || 'Welcome to EditFlow Pro!'}`
          } else {
            desc = `Your support request has been accepted. Team response: ${feedback || 'We are working on your issue.'}`
          }
        } else {
          if (isUpgradeRequest) {
            desc = `Your ${requestedPlan} Premium Upgrade request has been rejected. Details: ${feedback || 'Invalid UTR reference number or payment not received.'}`
          } else {
            desc = `Your support request has been rejected. Details: ${feedback || 'Does not match categories.'}`
          }
        }

        // Inform user: Insert notification activity for user
        const { error: userNotifError } = await adminClient.from('activities').insert({
          user_id: targetUserId,
          type: 'support_response',
          description: desc,
        })
        if (userNotifError) throw userNotifError

        // Email Notification via Resend
        try {
          const { data: userProfile } = await adminClient
            .from('profiles')
            .select('email, full_name')
            .eq('id', targetUserId)
            .maybeSingle()

          const userEmail = userProfile?.email
          const resendApiKey = Deno.env.get('RESEND_API_KEY')

          if (resendApiKey && userEmail) {
            const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') ?? 'supportbyeditflow@acsoft.online'
            
            let subjectText = '';
            let htmlContent = '';

            if (isUpgradeRequest) {
              if (action === 'accept') {
                subjectText = `🎉 Your EditFlow ${requestedPlan} Upgrade Approved!`;
                htmlContent = `
                  <!DOCTYPE html>
                  <html>
                  <head>
                    <meta charset="utf-8">
                    <title>EditFlow Premium Active</title>
                    <style>
                      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0B0F19; color: #E2E8F0; margin: 0; padding: 40px 20px; }
                      .container { max-width: 600px; margin: 0 auto; background-color: #111827; border: 1px solid #1F2937; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3); }
                      .header { text-align: center; margin-bottom: 30px; }
                      .title { color: #ffffff; font-size: 24px; font-weight: 800; margin: 10px 0; }
                      .badge { display: inline-block; background-color: #10B981; color: #ffffff; font-size: 11px; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.5px; margin-bottom: 20px; }
                      .content { font-size: 15px; line-height: 1.6; color: #9CA3AF; margin-bottom: 30px; }
                      .highlight { color: #ffffff; font-weight: 600; }
                      .footer { text-align: center; font-size: 12px; color: #6B7280; border-top: 1px solid #1F2937; padding-top: 20px; }
                    </style>
                  </head>
                  <body>
                    <div class="container">
                      <div class="header">
                        <span class="badge">PRO UPGRADE SUCCESS</span>
                        <div class="title">Your Premium Access is Active!</div>
                      </div>
                      <div class="content">
                        Hi <span class="highlight">${userProfile.full_name || 'there'}</span>,<br><br>
                        Great news! Your manual payment verification has been completed by our admin team, and your <strong>EditFlow Premium (${requestedPlan})</strong> subscription is now active!
                      </div>
                      <div class="footer">
                        Sent automatically by EditFlow Core • supportbyeditflow@acsoft.online
                      </div>
                    </div>
                  </body>
                  </html>
                `;
              } else {
                subjectText = `🚨 EditFlow Premium Upgrade Rejected`;
                htmlContent = `
                  <!DOCTYPE html>
                  <html>
                  <head>
                    <meta charset="utf-8">
                    <title>EditFlow Premium Upgrade Rejected</title>
                    <style>
                      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0B0F19; color: #E2E8F0; margin: 0; padding: 40px 20px; }
                      .container { max-width: 600px; margin: 0 auto; background-color: #111827; border: 1px solid #1F2937; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3); }
                      .header { text-align: center; margin-bottom: 30px; }
                      .title { color: #ffffff; font-size: 24px; font-weight: 800; margin: 10px 0; }
                      .badge { display: inline-block; background-color: #EF4444; color: #ffffff; font-size: 11px; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.5px; margin-bottom: 20px; }
                      .content { font-size: 15px; line-height: 1.6; color: #9CA3AF; margin-bottom: 30px; }
                      .highlight { color: #ffffff; font-weight: 600; }
                      .feedback-box { background-color: #1F2937; border-left: 4px solid #EF4444; border-radius: 4px; padding: 16px; margin: 24px 0; color: #E2E8F0; font-size: 14px; }
                      .btn { display: inline-block; background-color: #0D9488; color: #ffffff; text-decoration: none; font-size: 14px; font-weight: 700; padding: 12px 24px; border-radius: 8px; text-align: center; margin: 10px 0; }
                      .footer { text-align: center; font-size: 12px; color: #6B7280; border-top: 1px solid #1F2937; padding-top: 20px; }
                    </style>
                  </head>
                  <body>
                    <div class="container">
                      <div class="header">
                        <span class="badge">UPGRADE REJECTED</span>
                        <div class="title">Premium Upgrade Request Status</div>
                      </div>
                      <div class="content">
                        Hi <span class="highlight">${userProfile.full_name || 'there'}</span>,<br><br>
                        We reviewed your manual payment verification request for the <strong>EditFlow Pro ${requestedPlan} Plan</strong>, but we were unable to approve it at this time.<br>
                        This is usually due to an incorrect UTR/Reference number or matching payment not being found in our accounts.
                      </div>
                      <div class="feedback-box">
                        <strong>Reason/Feedback:</strong><br>
                        ${feedback || 'Invalid transaction UTR reference number or payment not received. Please verify and submit request again.'}
                      </div>
                      <div style="text-align: center;">
                        <a href="https://editflow.acsoft.online/app/#/settings" class="btn" style="color: #ffffff;">Try Upgrade Again</a>
                      </div>
                      <br>
                      <div class="footer">
                        Sent automatically by EditFlow Billing Core • supportbyeditflow@acsoft.online
                      </div>
                    </div>
                  </body>
                  </html>
                `;
              }
            } else {
              subjectText = action === 'accept' 
                ? 'EditFlow Support Ticket: Accepted & Resolving'
                : 'EditFlow Support Ticket Update';
            }

            if (!htmlContent) {
              htmlContent = `
                <!DOCTYPE html>
                <html>
                <head>
                  <meta charset="utf-8">
                <style>
                  body {
                    margin: 0;
                    padding: 0;
                    background-color: #080c0d;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    -webkit-font-smoothing: antialiased;
                  }
                  .wrapper {
                    width: 100%;
                    table-layout: fixed;
                    background-color: #080c0d;
                    padding: 48px 0;
                  }
                  .container {
                    max-width: 560px;
                    margin: 0 auto;
                    background-color: #101517;
                    border-radius: 12px;
                    border: 1px solid #1f2629;
                    border-top: 4px solid #0d9488;
                    overflow: hidden;
                    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
                  }
                  .header {
                    padding: 36px 36px 20px 36px;
                    text-align: center;
                    border-bottom: 1px solid #1f2629;
                  }
                  .logo {
                    width: 48px;
                    height: 48px;
                    margin-bottom: 14px;
                    border-radius: 12px;
                  }
                  .title {
                    font-size: 18px;
                    font-weight: 700;
                    color: #f8fafc;
                    margin: 0;
                    letter-spacing: -0.2px;
                  }
                  .content {
                    padding: 32px 36px 36px 36px;
                  }
                  .greeting {
                    font-size: 14px;
                    color: #f8fafc;
                    font-weight: 600;
                    margin-top: 0;
                    margin-bottom: 12px;
                  }
                  .message {
                    font-size: 13.5px;
                    color: #94a3b8;
                    line-height: 1.6;
                    margin: 0 0 24px 0;
                  }
                  .resolution-card {
                    background-color: #171d1f;
                    border-radius: 8px;
                    border: 1px solid #273135;
                    padding: 20px;
                    margin-bottom: 28px;
                  }
                  .status-row {
                    margin-bottom: 12px;
                  }
                  .status-badge {
                    font-size: 11px;
                    font-weight: 700;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    padding: 4px 10px;
                    border-radius: 4px;
                    display: inline-block;
                    background-color: ${action === 'accept' ? 'rgba(16, 185, 129, 0.12)' : 'rgba(244, 63, 94, 0.12)'};
                    color: ${action === 'accept' ? '#10b981' : '#f43f5e'};
                  }
                  .resolution-text {
                    font-size: 13.5px;
                    line-height: 1.6;
                    color: #f8fafc;
                    margin: 0;
                  }
                  .btn-container {
                    text-align: center;
                    margin-top: 16px;
                  }
                  .btn {
                    background-color: #0d9488;
                    color: #ffffff !important;
                    text-decoration: none;
                    font-weight: 600;
                    font-size: 13px;
                    padding: 10px 24px;
                    border-radius: 6px;
                    display: inline-block;
                  }
                  .footer {
                    padding: 24px 36px;
                    background-color: #0c0f11;
                    border-top: 1px solid #1f2629;
                    text-align: center;
                  }
                  .footer-text {
                    font-size: 11.5px;
                    color: #64748b;
                    line-height: 1.5;
                    margin: 0;
                  }
                  .footer-link {
                    color: #10b981;
                    text-decoration: none;
                  }
                </style>
              </head>
              <body>
                <div class="wrapper">
                  <div class="container">
                    <div class="header">
                      <img src="https://editflow.acsoft.online/logo.svg" alt="EditFlow Logo" class="logo">
                      <h1 class="title">Support Ticket Update</h1>
                    </div>
                    <div class="content">
                      <p class="greeting">Hello ${userProfile?.full_name || 'User'},</p>
                      <p class="message">The administration team has processed your support request ticket. The resolution details can be found below.</p>
                      
                      <div class="resolution-card">
                        <div class="status-row">
                          <span class="status-badge">${action === 'accept' ? 'Accepted' : 'Rejected'}</span>
                        </div>
                        <p class="resolution-text">
                          ${feedback || (action === 'accept' ? 'Your support request has been accepted. We are working on your issue.' : 'Your support request has been rejected.')}
                        </p>
                      </div>

                      <div class="btn-container">
                        <a href="https://editflow.acsoft.online/app/" class="btn" target="_blank">Access Dashboard</a>
                      </div>
                    </div>
                    <div class="footer">
                      <p class="footer-text">
                        If you have further inquiries, contact us at <a href="mailto:editflow@acsoft.online" class="footer-link">editflow@acsoft.online</a>.
                      </p>
                      <p class="footer-text" style="margin-top: 6px; font-size: 10.5px;">
                        © ${new Date().getFullYear()} EditFlow. All rights reserved.
                      </p>
                    </div>
                  </div>
                </div>
              </body>
              </html>
            `;
            }

            const res = await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${resendApiKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                from: fromEmail,
                to: userEmail,
                subject: subjectText,
                html: htmlContent,
              }),
            });

            if (!res.ok) {
              const errBody = await res.text();
              console.error('Resend API returned error status:', res.status, errBody);
            } else {
              console.log(`Resend email sent successfully to ${userEmail}`);
            }
          }
        } catch (err) {
          console.error('Failed to send Resend email:', err);
        }

        // Delete the ticket row
        const { error: deleteError } = await adminClient
          .from('support_tickets')
          .delete()
          .eq('id', ticketId)
        if (deleteError) throw deleteError

        // Audit log for admin action
        await adminClient.from('activities').insert({
          user_id: user?.id,
          type: 'admin_log',
          description: `${action === 'accept' ? 'Accepted' : 'Rejected'} support ticket (ID: ${ticketId}) for User: ${targetUserId}`,
        })

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'get_projects': {
        const { data: projects, error } = await adminClient
          .from('projects')
          .select('*, clients(name, company)')
          .order('created_at', { ascending: false })
        if (error) throw error

        const { data: profiles, error: profError } = await adminClient
          .from('profiles')
          .select('id, full_name, email')
        if (profError) throw profError

        const profileMap: Record<string, { full_name: string; email: string }> = {}
        for (const p of (profiles || [])) {
          profileMap[p.id] = { full_name: p.full_name, email: p.email }
        }

        const projectsWithProfiles = (projects || []).map(p => ({
          ...p,
          profiles: profileMap[p.user_id] || { full_name: 'None', email: '' }
        }))

        return new Response(JSON.stringify({ projects: projectsWithProfiles }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'get_storage': {
        let totalStorageBytes = 0
        const filesList: any[] = []
        const userUsage: { [key: string]: number } = {}

        const { data: buckets } = await adminClient.storage.listBuckets()
        const targetBuckets = buckets?.map(b => b.name) || ['video-reviews', 'voice-comments']
        
        for (const bucketName of targetBuckets) {
          const { data: files } = await adminClient.storage.from(bucketName).list()
          if (files) {
            for (const file of files) {
              const size = file.metadata?.size || 0
              totalStorageBytes += size
              filesList.push({
                name: file.name,
                bucket: bucketName,
                sizeBytes: size,
                createdAt: file.created_at,
              })

              const parts = file.name.split('/')
              if (parts.length > 1) {
                const folder = parts[0]
                userUsage[folder] = (userUsage[folder] || 0) + size
              }
            }
          }
        }

        // Fetch Postgres Database Size
        let dbSize = 0
        try {
          const { data: dbData } = await adminClient.rpc('get_database_size')
          if (dbData) {
            dbSize = Number(dbData)
          }
        } catch (e) {
          console.error('Error fetching database size:', e)
        }

        if (dbSize > 0) {
          filesList.push({
            name: "PostgreSQL Database (text, tables & metadata)",
            bucket: "database",
            sizeBytes: dbSize,
            createdAt: new Date().toISOString(),
          })
          userUsage["system_database"] = dbSize
        }

        filesList.sort((a, b) => b.sizeBytes - a.sizeBytes)

        return new Response(JSON.stringify({
          totalStorageUsed: totalStorageBytes + dbSize,
          largestFiles: filesList.slice(0, 20),
          userUsage,
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'send_broadcast': {
        const { messageType, title, description, targetType, selectedUserIds } = payload
        let targetUserIds: string[] = []
        
        if (targetType === 'all') {
          const { data: users } = await adminClient.from('profiles').select('id')
          targetUserIds = users?.map(u => u.id) || []
        } else if (targetType === 'admins') {
          const { data: users } = await adminClient.from('profiles').select('id').eq('role', 'admin')
          targetUserIds = users?.map(u => u.id) || []
        } else if (targetType === 'non_admins') {
          const { data: users } = await adminClient.from('profiles').select('id').eq('role', 'user')
          targetUserIds = users?.map(u => u.id) || []
        } else if (targetType === 'selected') {
          targetUserIds = selectedUserIds || []
        }

        if (targetUserIds.length > 0) {
          const inserts = targetUserIds.map(uid => ({
            user_id: uid,
            type: messageType,
            description: `${title}: ${description}`,
          }))

          const { error } = await adminClient.from('activities').insert(inserts)
          if (error) throw error
        }

        // Insert admin audit log
        await adminClient.from('activities').insert({
          user_id: user?.id,
          type: 'admin_log',
          description: `Broadcasted targeted ${messageType} notification: "${title}" to target "${targetType}"`,
        })

        return new Response(JSON.stringify({ success: true, count: targetUserIds.length }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'get_analytics': {
        const { data: projects } = await adminClient.from('projects').select('created_at, status')
        const { data: users } = await adminClient.from('profiles').select('created_at')

        return new Response(JSON.stringify({ projects, users }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'get_settings': {
        const { data: settings, error } = await adminClient.from('system_settings').select('*')
        if (error) throw error
        return new Response(JSON.stringify({ settings }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      case 'update_settings': {
        const { settingsList } = payload
        
        for (const item of settingsList) {
          const { error } = await adminClient
            .from('system_settings')
            .upsert({ key: item.key, value: item.value, updated_at: new Date().toISOString() })
          if (error) throw error
        }

        // Insert admin audit log
        await adminClient.from('activities').insert({
          user_id: user?.id,
          type: 'admin_log',
          description: `Updated global app settings configuration`,
        })

        return new Response(JSON.stringify({ success: true }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      default:
        return new Response(JSON.stringify({ error: 'Unknown action: ' + action }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message || error }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
