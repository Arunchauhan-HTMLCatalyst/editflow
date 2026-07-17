import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

function getResendCredentials() {
  let key = Deno.env.get('RESEND_API_KEY') || '';
  let from = Deno.env.get('RESEND_FROM_EMAIL') || 'supportbyeditflow@acsoft.online';
  key = key.replace(/['"]/g, '').trim();
  from = from.replace(/['"]/g, '').trim();
  return { key, from };
}

function getEmailTemplate(clientName: string, freelancerName: string, inviteCode: string, inviteUrl: string) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Portal Invitation</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          background-color: #090D16;
          color: #9CA3AF;
          margin: 0;
          padding: 40px 16px;
          -webkit-font-smoothing: antialiased;
        }
        .wrapper {
          max-width: 620px;
          margin: 0 auto;
          background-color: #111827;
          border: 1px solid #1F2937;
          border-top: 5px solid #10B981;
          border-radius: 12px;
          overflow: hidden;
          box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
        }
        .header {
          padding: 36px 36px 20px 36px;
          text-align: center;
          background: radial-gradient(circle at top, rgba(16, 185, 129, 0.05) 0%, rgba(17, 24, 39, 0) 70%);
          border-bottom: 1px solid #1F2937;
        }
        .badge {
          display: inline-block;
          background-color: rgba(16, 185, 129, 0.1);
          color: #10B981;
          font-size: 10px;
          font-weight: 700;
          letter-spacing: 0.8px;
          padding: 4px 12px;
          border-radius: 99px;
          text-transform: uppercase;
          margin-bottom: 16px;
          border: 1px solid rgba(16, 185, 129, 0.15);
        }
        .title {
          color: #FFFFFF;
          font-size: 20px;
          font-weight: 800;
          margin: 0;
          line-height: 1.3;
          letter-spacing: -0.4px;
        }
        .body {
          padding: 28px 36px 36px 36px;
          font-size: 13.5px;
          line-height: 1.6;
          color: #9CA3AF;
        }
        .body p {
          margin: 0 0 14px 0;
        }
        .code-box {
          display: block;
          background-color: #1F2937;
          border: 1px dashed #374151;
          color: #FFFFFF;
          font-family: monospace;
          font-size: 18px;
          font-weight: 700;
          letter-spacing: 1px;
          text-align: center;
          padding: 16px;
          border-radius: 8px;
          margin: 20px 0;
        }
        .btn {
          display: block;
          text-align: center;
          background-color: #10B981;
          color: #000000 !important;
          text-decoration: none;
          font-weight: 700;
          font-size: 14px;
          padding: 12px 24px;
          border-radius: 8px;
          margin: 24px 0 16px 0;
          box-shadow: 0 4px 14px 0 rgba(16, 185, 129, 0.3);
        }
        .footer {
          background-color: #0B0F19;
          padding: 24px 36px;
          text-align: center;
          font-size: 11px;
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
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="header">
          <img src="https://editflow.acsoft.online/app/icons/Icon-192.png" alt="EditFlow Logo" style="width: 52px; height: 52px; margin-bottom: 12px; border-radius: 10px; border: 1px solid rgba(16, 185, 129, 0.2);" />
          <br />
          <span class="badge">Portal Invitation</span>
          <h1 class="title">You have been invited to EditFlow</h1>
        </div>
        <div class="body">
          <p>Hello <span class="highlight">${clientName}</span>,</p>
          <p><span class="highlight">${freelancerName}</span> has invited you to access your projects on EditFlow. This portal allows you to review draft videos, add frame-by-frame comment feedback, and track project status in real time.</p>
          
          <p>Use the following invite code within the app to link your workspaces:</p>
          <div class="code-box">${inviteCode}</div>

          <a href="${inviteUrl}" class="btn" target="_blank">Accept Invitation & View Portal</a>
          
          <p style="margin-top: 20px; font-size: 12px; color: #6B7280;">If you don't have an EditFlow account yet, clicking the button above will take you to register. Once logged in, go to the Freelancers tab and enter the invite code above.</p>
        </div>
        <div class="footer">
          Powered by <a class="footer-link" href="https://editflow.acsoft.online">EditFlow</a>. All rights reserved.
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

  try {
    const { email, clientName, freelancerName, inviteCode, inviteUrl } = await req.json()

    if (!email || !clientName || !freelancerName || !inviteCode) {
      return new Response(JSON.stringify({ error: 'Missing required parameters' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { key: resendApiKey, from: fromEmail } = getResendCredentials()

    if (!resendApiKey) {
      return new Response(JSON.stringify({ error: 'Resend API key is not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const htmlBody = getEmailTemplate(clientName, freelancerName, inviteCode, inviteUrl || 'https://editflow.acsoft.online/login')

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({
        from: fromEmail,
        to: email,
        subject: `${freelancerName} invited you to EditFlow Portal`,
        html: htmlBody,
      }),
    })

    const resData = await res.json()
    if (!res.ok) {
      return new Response(JSON.stringify({ error: 'Resend error: ' + JSON.stringify(resData) }), {
        status: res.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ success: true, message: 'Email sent successfully', id: resData.id }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
