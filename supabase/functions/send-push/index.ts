// Supabase Edge Function — APNs + FCM push when a message is inserted.
//
// Trigger: Database webhook on public.messages INSERT.
// Body shape (sent by Supabase webhook): { type, table, record, schema, old_record? }
//
// What it does:
//   1. Read couple_id + sender_id from the inserted row.
//   2. Look up the OTHER user's row in users → grab their device_token (APNs)
//      + fcm_token (FCM) + the sender's myName for the alert title.
//   3. Fan out to whichever platform tokens are present:
//        device_token set → APNs (.p8 JWT, existing path)
//        fcm_token set    → FCM HTTPv1 (service-account OAuth token)
//
// What it intentionally does NOT do:
//   • Decrypt the message body. The server can't — it doesn't have the
//     chat key. The notification body is generic ("new message") so the
//     content stays E2EE.
//
// NOTE: Chinese string literals are written as \uXXXX escapes because the
// Supabase Dashboard editor's clipboard paste path mangles multi-byte UTF-8
// characters and produces "Unterminated string constant" deploy errors.
// Escapes are equivalent at runtime and survive the round-trip.
//   • Retry on failure. Push failures are silent — the chat still works
//     in foreground via Realtime, push is best-effort.
//
// Secrets the function expects (set via `supabase secrets set …` or in the
// Supabase Dashboard → Edge Functions → Secrets):
//   APNS_AUTH_KEY        — full .p8 contents including BEGIN/END lines
//   APNS_KEY_ID          — 10-char Key ID from Apple Developer
//   APNS_TEAM_ID         — C22JSRYW54
//   APNS_BUNDLE_ID       — michel.kit.us
//   FCM_SERVICE_ACCOUNT_JSON — full JSON of a Firebase service account with
//                              the cloudmessaging.messages.create permission.
//                              Download from Firebase Console → Project
//                              Settings → Service accounts → Generate new
//                              private key. Paste the entire JSON file.
//   FCM_PROJECT_ID       — Firebase project id (e.g. lover-app-xxxxx). Found
//                              in Firebase Console → Project Settings →
//                              General → Project ID. Same as the
//                              project_id field of the service-account JSON.
//   SUPABASE_URL         — auto-injected by Supabase
//   SUPABASE_SERVICE_ROLE_KEY  — auto-injected (server-only key for users lookup)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { create as jwtCreate, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

interface WebhookBody {
  type: string;       // "INSERT"
  table: string;      // "messages"
  record: {
    id: string;
    couple_id: string;
    sender_id: string;
    ciphertext_b64: string;
    created_at: string;
  };
  schema: string;
}

serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  let body: WebhookBody;
  try {
    body = await req.json();
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }
  if (body.table !== "messages" || body.type !== "INSERT") {
    return new Response("Ignored", { status: 200 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const { record } = body;

  // Look up the couple to find the partner's id.
  const coupleRes = await fetch(
    `${supabaseUrl}/rest/v1/couples?id=eq.${record.couple_id}&select=user_a_id,user_b_id`,
    {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    }
  );
  const couples: Array<{ user_a_id: string; user_b_id: string }> = await coupleRes.json();
  if (couples.length === 0) return new Response("Couple not found", { status: 200 });
  const couple = couples[0];
  const recipientId = couple.user_a_id === record.sender_id ? couple.user_b_id : couple.user_a_id;

  // Look up recipient's device_token + fcm_token + sender's display name.
  const usersRes = await fetch(
    `${supabaseUrl}/rest/v1/users?id=in.(${recipientId},${record.sender_id})&select=id,my_name,device_token,fcm_token`,
    {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    }
  );
  const users: Array<{ id: string; my_name: string; device_token: string | null; fcm_token: string | null }> = await usersRes.json();

  const recipient = users.find((u) => u.id === recipientId);
  const sender = users.find((u) => u.id === record.sender_id);
  if (!recipient) return new Response("Recipient not found", { status: 200 });
  if (!recipient.device_token && !recipient.fcm_token) {
    return new Response("No push tokens", { status: 200 });
  }

  // Fallback display name = "the other one" (Chinese chars escaped to keep
  // this file ASCII-safe for the Supabase Dashboard paste path, which mangles
  // multi-byte UTF-8 and produces "Unterminated string constant" deploy
  // errors). Runtime values pulled from DB are unaffected — only literals.
  // 對方 = "the other one"
  const senderName = sender?.my_name ?? "對方";
  // 傳咗訊息畀你 ♡ = "sent you a message <heart>"
  const alertBody = "傳咗訊息畢你 ♡";

  const results: Record<string, unknown> = { recipient: recipientId };

  // -- APNs branch --------------------------------------------------------
  if (recipient.device_token) {
    try {
      const apnsStatus = await sendApns({
        deviceToken: recipient.device_token,
        title: senderName,
        body: alertBody,
        threadId: record.couple_id,
      });
      results.apns_status = apnsStatus;
    } catch (e) {
      results.apns_error = String(e);
    }
  }

  // -- FCM branch ---------------------------------------------------------
  if (recipient.fcm_token) {
    try {
      const fcmStatus = await sendFcm({
        fcmToken: recipient.fcm_token,
        title: senderName,
        body: alertBody,
        threadId: record.couple_id,
      });
      results.fcm_status = fcmStatus;
    } catch (e) {
      results.fcm_error = String(e);
    }
  }

  return new Response(JSON.stringify(results), {
    headers: { "content-type": "application/json" },
  });
});

// === APNs ====================================================================

async function sendApns(args: {
  deviceToken: string;
  title: string;
  body: string;
  threadId: string;
}): Promise<number> {
  const keyP8 = Deno.env.get("APNS_AUTH_KEY")!;
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;

  const cryptoKey = await importApnsKey(keyP8);
  const jwt = await jwtCreate(
    { alg: "ES256", kid: keyId, typ: "JWT" },
    {
      iss: teamId,
      iat: getNumericDate(0),
    },
    cryptoKey
  );

  const payload = {
    aps: {
      alert: {
        title: args.title,
        body: args.body,
      },
      sound: "default",
      "thread-id": args.threadId,
    },
  };

  const res = await fetch(
    `https://api.push.apple.com/3/device/${args.deviceToken}`,
    {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    }
  );
  return res.status;
}

/// Imports an Apple ES256 .p8 private key into a CryptoKey usable by djwt.
async function importApnsKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
}

// === FCM HTTPv1 ==============================================================

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri: string;
  project_id: string;
}

let cachedFcmAccessToken: { token: string; expiresAt: number } | null = null;

async function sendFcm(args: {
  fcmToken: string;
  title: string;
  body: string;
  threadId: string;
}): Promise<number> {
  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  const accessToken = await getFcmAccessToken();

  // Wire-compat with iOS APNs payload: keep the same alert title/body and
  // a thread-id under android.collapseKey so the OS groups conversations.
  // Body must NOT contain decrypted message text — push stays generic.
  const payload = {
    message: {
      token: args.fcmToken,
      notification: {
        title: args.title,
        body: args.body,
      },
      android: {
        priority: "HIGH",
        collapse_key: args.threadId,
        notification: {
          tag: args.threadId,
          channel_id: "messages",
        },
      },
      data: {
        thread_id: args.threadId,
      },
    },
  };

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    }
  );
  return res.status;
}

async function getFcmAccessToken(): Promise<string> {
  const now = Date.now();
  if (cachedFcmAccessToken && cachedFcmAccessToken.expiresAt > now + 60_000) {
    return cachedFcmAccessToken.token;
  }

  const saJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!;
  const sa: ServiceAccount = JSON.parse(saJson);

  // Mint a Google OAuth 2.0 service-account JWT, then exchange for an
  // access token. Scope: FCM HTTPv1 send.
  const cryptoKey = await importGooglePrivateKey(sa.private_key);
  const iat = Math.floor(now / 1000);
  const exp = iat + 3600;
  const assertion = await jwtCreate(
    { alg: "RS256", typ: "JWT" },
    {
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: sa.token_uri,
      iat,
      exp,
    },
    cryptoKey
  );

  const tokenRes = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!tokenRes.ok) {
    throw new Error(`Google token exchange failed: ${tokenRes.status}`);
  }
  const tokenJson: { access_token: string; expires_in: number } = await tokenRes.json();
  cachedFcmAccessToken = {
    token: tokenJson.access_token,
    expiresAt: now + tokenJson.expires_in * 1000,
  };
  return tokenJson.access_token;
}

async function importGooglePrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}
