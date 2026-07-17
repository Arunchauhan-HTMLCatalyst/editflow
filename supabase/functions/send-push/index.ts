import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

// Simple helper to sign JWT for Google Auth without external heavy library dependencies
async function getAccessToken(serviceAccount: any): Promise<string> {
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    iat: now,
    exp: now + 3600,
  };

  // Convert PEM private key string to ArrayBuffer
  const pem = serviceAccount.private_key;
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = pem
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s+/g, "");
  
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const encoder = new TextEncoder();
  const unsignedToken =
    btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_") +
    "." +
    btoa(JSON.stringify(payload)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encoder.encode(unsignedToken)
  );

  const signedToken =
    unsignedToken +
    "." +
    btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${signedToken}`,
  });

  const data = await res.json();
  if (data.error) {
    throw new Error(`Google Auth token exchange failed: ${data.error_description || data.error}`);
  }
  return data.access_token;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { recipientUserId, title, body, route } = await req.json()

    if (!recipientUserId) {
      return new Response(
        JSON.stringify({ error: "recipientUserId is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // 1. Fetch user fcm_token from database using Supabase Client with service role key
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const { data: profile, error: dbError } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", recipientUserId)
      .single()

    if (dbError || !profile) {
      console.warn(`[send-push] Profile not found or database error: ${dbError?.message}`);
      return new Response(
        JSON.stringify({ success: false, message: "Profile not found or db error" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const fcmToken = profile.fcm_token
    if (!fcmToken) {
      console.info(`[send-push] User ${recipientUserId} has no registered FCM token. Skipping notification.`);
      return new Response(
        JSON.stringify({ success: true, message: "User has no registered FCM token" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // 2. Fetch Google credentials from environment variables
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")
    if (!serviceAccountJson) {
      console.error("[send-push] FIREBASE_SERVICE_ACCOUNT environment variable is not configured.");
      return new Response(
        JSON.stringify({
          error: "FIREBASE_SERVICE_ACCOUNT environment variable is not configured. Please upload your Firebase Service Account JSON secret to Supabase.",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    const accessToken = await getAccessToken(serviceAccount)

    // 3. Make HTTP request to Google FCM API
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`
    const payload = {
      message: {
        token: fcmToken,
        notification: {
          title: title || "EditFlow Alert",
          body: body || "",
        },
        data: {
          route: route || "/dashboard",
        },
        webpush: {
          notification: {
            title: title || "EditFlow Alert",
            body: body || "",
            icon: "/app/logo.svg",
            badge: "/app/favicon.png",
          },
          fcm_options: {
            link: `https://editflow.acsoft.online/app/#${route || "/dashboard"}`,
          },
        },
      },
    }

    const fcmResponse = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(payload),
    })

    const fcmResult = await fcmResponse.json()
    if (!fcmResponse.ok) {
      console.error(`[send-push] FCM API error: ${JSON.stringify(fcmResult)}`);
      return new Response(
        JSON.stringify({ error: "FCM API error", details: fcmResult }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.info(`[send-push] Successfully sent push notification to user ${recipientUserId}`);
    return new Response(
      JSON.stringify({ success: true, details: fcmResult }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error: any) {
    console.error(`[send-push] Unhandled error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
