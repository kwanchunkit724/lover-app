// Browser-side Supabase client. Use this in Client Components and
// useEffect/useState hooks. For Server Components / Route Handlers /
// Server Actions, import from ./server instead.
//
// The publishable anon key is intentionally embedded — RLS enforces all
// per-user access. The service_role key is never shipped to the browser.

import { createBrowserClient } from "@supabase/ssr";

export const createClient = () =>
  createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
