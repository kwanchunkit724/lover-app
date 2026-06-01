// Landing router. Decides where to send the user based on their state:
//   no session       → /login
//   no users row     → /onboarding
//   no couple row    → /pair
//   paired           → /chat
//
// Runs as a Server Component so the decision happens on the server and
// avoids a flash of the wrong page.

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  // Has a profile row? Surface a query error instead of treating it as
  // "no row" (which would wrongly bounce a real user to /onboarding).
  const { data: profile, error: profileErr } = await supabase
    .from("users")
    .select("id")
    .eq("id", user.id)
    .maybeSingle();

  if (profileErr) throw profileErr;
  if (!profile) redirect("/onboarding");

  // Is paired?
  const { data: couple, error: coupleErr } = await supabase
    .from("couples")
    .select("id")
    .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
    .maybeSingle();

  if (coupleErr) throw coupleErr;
  if (!couple) redirect("/pair");

  redirect("/chat");
}
