-- v1.6.1 Feature 7 — mood + cheer.
--
-- Each partner sets a current mood; the other sees it. If the partner is sad/
-- angry you "cheer" them by tapping N times; on completion a cheer row is
-- written and the cheered partner's mood resets to happy. Realtime delivery
-- reuses the proven postgres_changes path (same as messages/play_history) —
-- no Realtime broadcast (kept on the known-good API surface).
--
-- Allowed moods (server-enforced): happy, sad, angry, love, tired.

------------------------------------------------------------------------------
-- 1. DURABLE MOOD on users  (partner-read already covered by users_select_partner)
------------------------------------------------------------------------------

alter table public.users
    add column if not exists mood text
        check (mood is null or mood in ('happy','sad','angry','love','tired')),
    add column if not exists mood_updated_at timestamptz;

create or replace function public.set_mood(p_mood text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;
    if p_mood is not null and p_mood not in ('happy','sad','angry','love','tired') then
        raise exception 'invalid_mood';
    end if;
    update public.users
        set mood = p_mood, mood_updated_at = now()
        where id = auth.uid();
end $$;

revoke all on function public.set_mood(text) from public;
grant execute on function public.set_mood(text) to authenticated;

------------------------------------------------------------------------------
-- 2. CHEERS — one row per completed cheer, realtime-published so the cheered
--    partner gets a live celebration.
------------------------------------------------------------------------------

create table if not exists public.cheers (
    id            uuid primary key default gen_random_uuid(),
    couple_id     uuid not null references public.couples(id) on delete cascade,
    from_user_id  uuid not null references public.users(id)   on delete cascade,
    to_user_id    uuid not null references public.users(id)   on delete cascade,
    mood          text not null,
    created_at    timestamptz not null default now()
);

create index if not exists cheers_couple_idx on public.cheers(couple_id, created_at desc);

alter table public.cheers enable row level security;

create policy cheers_select_member on public.cheers for select using (
    exists (
        select 1 from public.couples c
         where c.id = cheers.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

create policy cheers_insert_member on public.cheers for insert with check (
    from_user_id = auth.uid()
    and exists (
        select 1 from public.couples c
         where c.id = cheers.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

alter publication supabase_realtime add table public.cheers;
