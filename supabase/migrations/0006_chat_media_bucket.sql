-- Phase 4c — encrypted media storage.
--
-- Creates a private Storage bucket "chat-media" with policies that:
--   • SELECT: any couple member can read objects whose path starts with
--             "couple-{their_couple_id}/"
--   • INSERT: same scope, only for the user's own couple
--
-- Object payload is the AES-GCM SealedBox.combined of the original media
-- bytes, encrypted with the same chat key derived in CryptoService. The
-- server stores opaque ciphertext only; thumbnails / EXIF / preview must
-- be generated client-side post-decrypt.
--
-- Path convention (enforced by the policy): couple-<couple-id>/<uuid>.bin

-- Create the bucket if it doesn't exist. No idempotent helper exists — use
-- ON CONFLICT.
insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', false)
on conflict (id) do nothing;

------------------------------------------------------------------------------
-- Policies on storage.objects scoped to bucket_id = 'chat-media'

-- A user can SELECT objects whose path's first segment matches a couple
-- they're a member of.
create policy chat_media_select_member
    on storage.objects for select
    using (
        bucket_id = 'chat-media'
        and exists (
            select 1 from public.couples c
             where (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
               and split_part(name, '/', 1) = 'couple-' || c.id::text
        )
    );

-- A user can INSERT objects under their own couple's path.
create policy chat_media_insert_member
    on storage.objects for insert
    with check (
        bucket_id = 'chat-media'
        and exists (
            select 1 from public.couples c
             where (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
               and split_part(name, '/', 1) = 'couple-' || c.id::text
        )
    );

-- No update/delete from clients — media is permanent in v0.4.x.
