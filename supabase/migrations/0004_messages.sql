-- Phase 4a — E2EE chat schema.
--
-- users.public_key  — base64 of the user's 32-byte X25519 raw public key,
--                     uploaded by AuthService on first sign-in. RLS already
--                     allows the partner to SELECT this row, so chat key
--                     derivation works without any extra policy.
--
-- messages          — opaque ciphertext blobs. Server never sees plaintext.
--                     ciphertext_b64 = base64(AES.GCM SealedBox.combined),
--                     so it's nonce(12) + cipher + tag(16) in one blob.
--
-- RLS:
--   SELECT: any member of the couple this message belongs to
--   INSERT: only the sender, and only into a couple they're a member of
--   No UPDATE / DELETE for now (chat history is permanent in v0.4.x).

------------------------------------------------------------------------------
-- 1. users.public_key

alter table public.users
    add column if not exists public_key text;

------------------------------------------------------------------------------
-- 2. messages

create table public.messages (
    id              uuid primary key default gen_random_uuid(),
    couple_id       uuid not null references public.couples(id) on delete cascade,
    sender_id       uuid not null references public.users(id)   on delete cascade,
    ciphertext_b64  text not null check (length(ciphertext_b64) between 1 and 65536),
    created_at      timestamptz not null default now()
);

-- Common query pattern: latest N messages for a couple, oldest first when paged.
create index messages_couple_created_idx on public.messages(couple_id, created_at);

alter table public.messages enable row level security;

-- A user can read messages from their own couple.
create policy messages_select_member on public.messages for select using (
    exists (
        select 1 from public.couples c
         where c.id = messages.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

-- A user can insert only as themselves into a couple they're part of.
create policy messages_insert_sender on public.messages for insert with check (
    sender_id = auth.uid()
    and exists (
        select 1 from public.couples c
         where c.id = messages.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);
