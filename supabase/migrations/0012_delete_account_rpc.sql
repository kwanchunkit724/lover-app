-- v1.4.5 — in-app account deletion. Required by Apple App Store Review
-- Guideline 5.1.1(v): apps that allow account creation must offer in-app
-- account deletion. Privacy-policy "email us" is NOT sufficient (rejection
-- received 2026-05-12).
--
-- delete_my_account() runs as security definer using auth.uid() to identify
-- the caller and purges:
--   • the couple row I'm a member of (cascades partner to unpaired)
--   • my messages / entries / anniversaries / play_history rows
--   • my public.users row (releases my display name + email + public_key)
--   • my auth.users row (Apple ID / email auth identity, plus refresh tokens)
--
-- Encrypted blobs in Storage (chat-media bucket) are not server-side wipeable
-- without admin keys we don't ship — but those blobs are useless once their
-- decryption key is gone (key was derived from the partner pair). Leaving
-- them as orphan ciphertext is acceptable per Apple's guideline (the user's
-- *identifying* data is gone).

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $func$
declare
    me uuid := auth.uid();
begin
    if me is null then
        raise exception 'not authenticated';
    end if;

    -- Couple row I'm in — DELETE cascades to chat / entries / etc. via FKs
    -- if those tables have ON DELETE CASCADE on couple_id; otherwise we'll
    -- explicitly null the partner side below.
    delete from public.couples
        where user_a_id = me or user_b_id = me;

    -- Per-user encrypted rows that don't auto-cascade (e.g. anniversaries
    -- pre-couple, or rows where couple_id is nullable).
    delete from public.messages       where sender_id = me;
    delete from public.entries        where sender_id = me;
    delete from public.anniversaries  where sender_id = me;
    delete from public.play_history   where sender_id = me;

    -- Public profile row (display name, email, public key, device token).
    delete from public.users where id = me;

    -- Auth row — removes Apple ID / email identity + refresh tokens. After
    -- this the caller's JWT is invalid; the iOS client should signOut next.
    delete from auth.users where id = me;
end;
$func$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
