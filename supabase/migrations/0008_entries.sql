-- Phase 5 v0.5.1 — E2EE shared timetable entries.
--
-- Same shape as anniversaries: opaque ciphertext blobs, RLS scopes
-- read/write to couple members, realtime publication for live sync.
--
-- The plaintext payload (EntryPayload in Swift) carries title, date, time,
-- location, notes, tag, who, isSpecial — everything the existing TimeView /
-- EntryDetailView consumed from MockData.entries.

create table public.entries (
    id              uuid primary key default gen_random_uuid(),
    couple_id       uuid not null references public.couples(id) on delete cascade,
    sender_id       uuid not null references public.users(id)   on delete cascade,
    ciphertext_b64  text not null check (length(ciphertext_b64) between 1 and 32768),
    created_at      timestamptz not null default now()
);

create index entries_couple_idx on public.entries(couple_id, created_at);

alter table public.entries enable row level security;

create policy entries_select_member on public.entries for select using (
    exists (
        select 1 from public.couples c
         where c.id = entries.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

create policy entries_insert_member on public.entries for insert with check (
    sender_id = auth.uid()
    and exists (
        select 1 from public.couples c
         where c.id = entries.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

create policy entries_delete_member on public.entries for delete using (
    exists (
        select 1 from public.couples c
         where c.id = entries.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

alter publication supabase_realtime add table public.entries;
