// OAuth callback — Supabase redirects here after Google sign-in success.
// Exchanges the `code` for a session (cookies set via @supabase/ssr),
// then redirects to the original `next` path (or / by default).

import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const GET = async (request: Request) => {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = url.searchParams.get("next") ?? "/";

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) {
      return NextResponse.redirect(
        `${url.origin}/login?error=${encodeURIComponent(error.message)}`,
      );
    }
  }
  return NextResponse.redirect(`${url.origin}${next}`);
};
