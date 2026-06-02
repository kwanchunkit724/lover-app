-- v1.6.5 Feature — shared quick checklist (short-term memory: what to buy /
-- what to do). E2EE: the item text is sealed in ciphertext_b64 with the
-- couple's chat key (same as messages/entries); `done` is a plaintext boolean
-- so it can be toggled without a decrypt. Realtime so both partners stay in
-- sync.

create table if not exists public.checklist_items (
    id             uuid primary key default gen_random_uuid(),
    couple_id      uuid not null references public.couples(id) on delete cascade,
    sender_id      uuid not null references public.users(id)   on delete cascade,
    ciphertext_b64 text not null check (length(ciphertext_b64) between 1 and 4096),
    done           boolean not null default false,
    created_at     timestamptz not null default now()
);

create index if not exists checklist_couple_idx on public.checklist_items(couple_id, created_at desc);

alter table public.checklist_items enable row level security;

create policy checklist_select_member on public.checklist_items for select using (
    exists (select 1 from public.couples c
             where c.id = checklist_items.couple_id
               and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid()))
);

create policy checklist_insert_member on public.checklist_items for insert with check (
    sender_id = auth.uid()
    and exists (select 1 from public.couples c
                 where c.id = checklist_items.couple_id
                   and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid()))
);

create policy checklist_update_member on public.checklist_items for update using (
    exists (select 1 from public.couples c
             where c.id = checklist_items.couple_id
               and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid()))
);

create policy checklist_delete_member on public.checklist_items for delete using (
    exists (select 1 from public.couples c
             where c.id = checklist_items.couple_id
               and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid()))
);

alter publication supabase_realtime add table public.checklist_items;
