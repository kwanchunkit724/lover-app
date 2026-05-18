-- Phase C — real presence backing.
--
-- Two parts:
--   1. users.last_seen_at column maintained client-side via heartbeat RPC.
--      Falls back to "上次在線 X 分鐘前" in the chat header when the partner
--      is offline (presence channel sees no payload).
--   2. update_last_seen() RPC — SECURITY DEFINER so the calling user can
--      bump their own row's last_seen_at = now() without needing a direct
--      update policy.
--
-- The partner-read side is already covered by users_select_partner in
-- 0001_initial_schema.sql:84 — that policy lets either side of a couple
-- read each other's full row, which includes the new column.

------------------------------------------------------------------------------
-- 1. SCHEMA
------------------------------------------------------------------------------

alter table public.users
    add column if not exists last_seen_at timestamptz;

------------------------------------------------------------------------------
-- 2. HEARTBEAT RPC
------------------------------------------------------------------------------

create or replace function public.update_last_seen()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;
    update public.users
        set last_seen_at = now()
        where id = auth.uid();
end $$;

revoke all on function public.update_last_seen() from public;
grant execute on function public.update_last_seen() to authenticated;
