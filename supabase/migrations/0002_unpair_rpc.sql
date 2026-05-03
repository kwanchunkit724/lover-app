-- Phase 3c — atomic unpair RPC.
--
-- Deletes the couple row that includes the calling user. Either side can
-- unpair — both sides immediately fall back to PairingView on their next
-- couple-state refresh.
--
-- SECURITY DEFINER + the auth.uid() check keeps it safe: a caller can only
-- destroy a couple they're already part of.
--
-- Note: this does NOT delete messages / entries / anniversaries. Those
-- tables don't exist yet (Phase 4+); when they're added we'll cascade
-- on couples.id or rotate keys here.

create or replace function public.unpair()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    delete from couples
     where user_a_id = auth.uid()
        or user_b_id = auth.uid();
end $$;

revoke all on function public.unpair() from public;
grant execute on function public.unpair() to authenticated;
