// Server-side Supabase client for Server Components, Route Handlers, and
// Server Actions. Uses cookies() so the session is read from the request
// and writes propagate via Set-Cookie. The middleware (../middleware.ts)
// refreshes expired access tokens so server callers always see a fresh
// session.

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export const createClient = async () => {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (cookiesToSet) => {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Called from a Server Component — set is not allowed. The
            // middleware handles cookie writes for those paths, so this
            // can safely be ignored.
          }
        },
      },
    },
  );
};
