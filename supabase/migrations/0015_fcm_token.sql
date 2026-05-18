-- Phase B Round 2 — Android FCM push support.
--
-- iOS uploads its APNs hex token into public.users.device_token via the
-- set_device_token() RPC (see 0005_realtime_publication.sql). We need a
-- second column for Firebase Cloud Messaging tokens so the send-push Edge
-- Function can branch by platform at delivery time.
--
-- Why a separate column instead of a `platform` discriminator on
-- device_token? A single user could in principle be signed in on both
-- platforms (iPad + Pixel) — keeping the two tokens side-by-side lets us
-- fan out to both without juggling row history. Each platform's sign-in
-- writes its own column and clears it on sign-out.
--
-- The Edge Function (supabase/functions/send-push/index.ts) selects both
-- columns for the recipient and:
--   • if device_token is set → APNs HTTP/2 with the .p8 JWT (existing path)
--   • if fcm_token is set    → FCM HTTPv1 with a service-account OAuth token
-- Both can fire for the same message — the partner just gets the push on
-- whichever device is awake.

alter table public.users
    add column if not exists fcm_token text;

-- RPC mirror of set_device_token(). Same pattern: caller is authenticated,
-- updates only their own row.
create or replace function public.set_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    update users set fcm_token = p_token where id = auth.uid();
end;
$$;

revoke all on function public.set_fcm_token(text) from public;
grant execute on function public.set_fcm_token(text) to authenticated;
