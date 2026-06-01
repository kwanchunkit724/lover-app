// OAuth callback — Supabase redirects here after Google sign-in success.
// Exchanges the `code` for a session (cookies set via @supabase/ssr),
// then redirects to the original `next` path (or / by default).

import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const GET = async (request: Request) => {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = url.searchParams.get("next") ?? "/";

  // Validate `next` is a same-origin relative path before redirecting to it.
  // Resolving against the origin and asserting the origin neutralizes
  // protocol-relative (//evil), userinfo (@evil), and backslash tricks that
  // would otherwise turn this trusted auth URL into an open redirect.
  let safeNext = "/";
  try {
    const candidate = new URL(next, url.origin);
    if (candidate.origin === url.origin) {
      safeNext = candidate.pathname + candidate.search + candidate.hash;
    }
  } catch {
    safeNext = "/";
  }

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) {
      return NextResponse.redirect(
        `${url.origin}/login?error=${encodeURIComponent(error.message)}`,
      );
    }
  }
  return NextResponse.redirect(`${url.origin}${safeNext}`);
};
