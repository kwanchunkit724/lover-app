import { redirect } from "next/navigation";

/** KK: profile folded into 我哋 (/us). */
export default function ProfileRedirect() {
  redirect("/us");
}
