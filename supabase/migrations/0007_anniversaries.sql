-- Phase 5 v0.5.0 — E2EE shared anniversaries.
--
-- Same shape as messages: opaque ciphertext blobs scoped to a couple.
-- The plaintext (encoded as JSON, encrypted with the chat key) holds
-- title / baseDate / recur / kaomoji / emoji / subtitle — see
-- AnniversaryPayload in Swift.
--
-- Either partner can add or delete anniversaries (it's a shared list).
-- We track sender_id for audit + future "who added this" UI.

create table public.anniversaries (
    id              uuid primary key default gen_random_uuid(),
    couple_id       uuid not null references public.couples(id) on delete cascade,
    sender_id       uuid not null references public.users(id)   on delete cascade,
    ciphertext_b64  text not null check (length(ciphertext_b64) between 1 and 16384),
    created_at      timestamptz not null default now()
);

create index anniversaries_couple_idx on public.anniversaries(couple_id, created_at);

alter table public.anniversaries enable row level security;

-- A user can read all anniversaries from their own couple.
create policy anniversaries_select_member on public.anniversaries for select using (
    exists (
        select 1 from public.couples c
         where c.id = anniversaries.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

-- Either partner can insert (sender_id must be themselves, couple must
-- include them).
create policy anniversaries_insert_member on public.anniversaries for insert with check (
    sender_id = auth.uid()
    and exists (
        select 1 from public.couples c
         where c.id = anniversaries.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

-- Either partner can delete any anniversary in their couple. Couples are a
-- trust unit — both have equal write access.
create policy anniversaries_delete_member on public.anniversaries for delete using (
    exists (
        select 1 from public.couples c
         where c.id = anniversaries.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

-- Realtime so when partner adds/removes, my list updates without a refresh.
alter publication supabase_realtime add table public.anniversaries;
