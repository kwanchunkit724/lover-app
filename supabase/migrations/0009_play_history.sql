-- Phase 6 v0.6.x — E2EE shared activity history (play tab).
--
-- ONE table that holds three different kinds of records, distinguished by
-- the encrypted payload's `kind` field. We could have shipped three tables
-- but: same RLS, same realtime channel, same access pattern (insert-only,
-- read-by-couple). One table = simpler ops + fewer migrations.
--
-- Payload kinds (decrypted client-side):
--   v0.6.0  date_card    — { cardId, doneAtISO, reflection? }
--   v0.6.1  journal      — { dayISO, text }
--   v0.6.2  quiz_answer  — { questionId, answer, answeredAtISO }
--
-- Adding a new kind doesn't need a migration.

create table public.play_history (
    id              uuid primary key default gen_random_uuid(),
    couple_id       uuid not null references public.couples(id) on delete cascade,
    sender_id       uuid not null references public.users(id)   on delete cascade,
    ciphertext_b64  text not null check (length(ciphertext_b64) between 1 and 16384),
    created_at      timestamptz not null default now()
);

create index play_history_couple_idx on public.play_history(couple_id, created_at desc);

alter table public.play_history enable row level security;

create policy play_history_select_member on public.play_history for select using (
    exists (
        select 1 from public.couples c
         where c.id = play_history.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

create policy play_history_insert_member on public.play_history for insert with check (
    sender_id = auth.uid()
    and exists (
        select 1 from public.couples c
         where c.id = play_history.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

create policy play_history_delete_member on public.play_history for delete using (
    exists (
        select 1 from public.couples c
         where c.id = play_history.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

alter publication supabase_realtime add table public.play_history;
