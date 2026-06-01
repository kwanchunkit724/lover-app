// Session-refresh middleware. Called from the root middleware.ts on every
// request. Reads the request cookies, refreshes the access token if needed,
// and writes any updated session cookies back onto the response.
//
// Per @supabase/ssr docs: DO NOT run any logic between createServerClient
// and supabase.auth.getUser() — that's what refreshes the session.

import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export const updateSession = async (request: NextRequest) => {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // IMPORTANT: do not run any logic between createServerClient and getUser.
  // A simple error here will cause hard-to-debug session sync issues.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Redirect unauthenticated users away from app-protected paths.
  const pathname = request.nextUrl.pathname;
  const isProtected =
    pathname.startsWith("/chat") ||
    pathname.startsWith("/time") ||
    pathname.startsWith("/memory") ||
    pathname.startsWith("/us") ||
    pathname.startsWith("/pair") ||
    pathname.startsWith("/onboarding") ||
    pathname.startsWith("/profile");

  if (isProtected && !user) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", pathname);
    return NextResponse.redirect(url);
  }

  return response;
};
