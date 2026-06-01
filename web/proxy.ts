import { updateSession } from "@/lib/supabase/middleware";
import type { NextRequest } from "next/server";

export const proxy = (request: NextRequest) => updateSession(request);

export const config = {
  matcher: [
    // Run on all paths except static assets, Next internals, favicon.
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|woff|woff2)$).*)",
  ],
};
