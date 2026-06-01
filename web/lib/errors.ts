// Best-effort error → string. Supabase PostgrestError is a plain object
// with `message` + `details` + `hint` + `code`; it does NOT extend Error,
// so `e instanceof Error` returns false and naive `String(e)` yields
// "[object Object]". This helper flattens the common shapes.

export const errMsg = (e: unknown): string => {
  if (e == null) return "(unknown error)";
  if (typeof e === "string") return e;
  if (e instanceof Error) return e.message;
  if (typeof e === "object") {
    const o = e as Record<string, unknown>;
    if (typeof o.message === "string") {
      const extra = [o.code, o.hint, o.details]
        .filter((v): v is string => typeof v === "string" && v.length > 0)
        .join(" · ");
      return extra ? `${o.message} (${extra})` : o.message;
    }
    try {
      return JSON.stringify(e);
    } catch {
      return Object.prototype.toString.call(e);
    }
  }
  return String(e);
};
