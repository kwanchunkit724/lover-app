-- Phase 4b — enable Postgres logical replication of messages so the iOS
-- client's Supabase Realtime channel receives INSERT events the moment the
-- partner's row hits the table.
--
-- Supabase ships a default publication called supabase_realtime that
-- broadcasts to the realtime service. Adding our messages table to it is
-- the one server-side toggle needed for live chat — RLS still applies on
-- the receiving side, so we don't widen exposure.
--
-- Also adds users.device_token + a small RPC to write it. Phase 4b's iOS
-- scaffold registers for APNs and stashes the token here; actual push
-- delivery (an Edge Function listening for messages INSERT and calling
-- APNs) is queued for Phase 6 polish.

------------------------------------------------------------------------------
-- Realtime: enable INSERT broadcast on messages

alter publication supabase_realtime add table public.messages;

------------------------------------------------------------------------------
-- APNs device token storage

alter table public.users
    add column if not exists device_token text;

-- RPC so the client doesn't need a separate update path that bypasses RLS.
create or replace function public.set_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;
    update users set device_token = p_token where id = auth.uid();
end $$;

revoke all on function public.set_device_token(text) from public;
grant execute on function public.set_device_token(text) to authenticated;
