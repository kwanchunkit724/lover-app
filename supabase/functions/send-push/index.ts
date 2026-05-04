// Supabase Edge Function — APNs push when a message is inserted.
//
// Trigger: Database webhook on public.messages INSERT.
// Body shape (sent by Supabase webhook): { type, table, record, schema, old_record? }
//
// What it does:
//   1. Read couple_id + sender_id from the inserted row.
//   2. Look up the OTHER user's row in users → grab their device_token + the
//      sender's myName for the alert title.
//   3. Mint an APNs JWT using the .p8 key + key_id + team_id (env secrets).
//   4. POST to APNs production endpoint with bundle id `michel.kit.us`.
//
// What it intentionally does NOT do:
//   • Decrypt the message body. The server can't — it doesn't have the
//     chat key. The notification body is generic ("傳咗訊息畀你") so the
//     content stays E2EE.
//   • Retry on failure. APNs failures are silent — the chat still works
//     in foreground via Realtime, push is best-effort.
//
// Secrets the function expects (set via `supabase secrets set …` or in the
// Supabase Dashboard → Edge Functions → Secrets):
//   APNS_AUTH_KEY        — full .p8 contents including BEGIN/END lines
//   APNS_KEY_ID          — 10-char Key ID from Apple Developer
//   APNS_TEAM_ID         — C22JSRYW54
//   APNS_BUNDLE_ID       — michel.kit.us
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

  // Look up recipient's device_token + sender's display name.
  const usersRes = await fetch(
    `${supabaseUrl}/rest/v1/users?id=in.(${recipientId},${record.sender_id})&select=id,my_name,device_token`,
    {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    }
  );
  const users: Array<{ id: string; my_name: string; device_token: string | null }> = await usersRes.json();

  const recipient = users.find((u) => u.id === recipientId);
  const sender = users.find((u) => u.id === record.sender_id);
  if (!recipient?.device_token) return new Response("No device token", { status: 200 });

  // Mint the APNs JWT (valid for ~1 hour; we mint per-call, simple).
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

  const senderName = sender?.my_name ?? "對方";
  const apnsBody = {
    aps: {
      alert: {
        title: senderName,
        body: "傳咗訊息畀你 ♡",
      },
      sound: "default",
      "thread-id": record.couple_id,
    },
  };

  const apnsRes = await fetch(
    `https://api.push.apple.com/3/device/${recipient.device_token}`,
    {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(apnsBody),
    }
  );

  // 200 = delivered to APNs (not necessarily to device). Anything else
  // we just log and shrug; foreground delivery still works via Realtime.
  return new Response(
    JSON.stringify({
      apns_status: apnsRes.status,
      recipient: recipientId,
    }),
    { headers: { "content-type": "application/json" } }
  );
});

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
