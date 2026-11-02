import { redirect } from "next/navigation";

/** KK: 時間簿 removed → 記憶空間. */
export default function TimeRedirect() {
  redirect("/memory");
}
