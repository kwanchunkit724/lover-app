-- v1.6.1 Feature 6 — "next meet-up" stickiness loop.
--
-- The couple sets the next day they'll meet. It shows as a countdown in the
-- chat room AND the Time tab. When the day arrives both partners are prompted
-- to take a selfie; the selfies attach to the meet-up. When both have taken
-- one the meet-up is completed.
--
-- meet_date is plaintext (needed for the countdown + "is there a due meet-up"
-- query). Selfies are E2EE: the columns hold Supabase Storage paths to
-- AES-GCM-encrypted images (same chat-media bucket + chat key as photos), so
-- the bytes at rest are encrypted; only the storage path is in the row.
-- a/b map to the couple's user_a_id / user_b_id.

create table if not exists public.meetups (
    id              uuid primary key default gen_random_uuid(),
    couple_id       uuid not null references public.couples(id) on delete cascade,
    created_by      uuid not null references public.users(id)   on delete cascade,
    meet_date       date not null,
    title           text not null default '下次見面',
    status          text not null default 'upcoming'
                        check (status in ('upcoming','completed','cancelled')),
    selfie_a_handle text,
    selfie_b_handle text,
    created_at      timestamptz not null default now(),
    completed_at    timestamptz
);

create index if not exists meetups_couple_idx on public.meetups(couple_id, meet_date);

alter table public.meetups enable row level security;

create policy meetups_select_member on public.meetups for select using (
    exists (select 1 from public.couples c
             where c.id = meetups.couple_id
               and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid()))
);

create policy meetups_insert_member on public.meetups for insert with check (
    created_by = auth.uid()
    and exists (select 1 from public.couples c
                 where c.id = meetups.couple_id
                   and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid()))
);

create policy meetups_update_member on public.meetups for update using (
    exists (select 1 from public.couples c
             where c.id = meetups.couple_id
               and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid()))
);

create policy meetups_delete_member on public.meetups for delete using (
    exists (select 1 from public.couples c
             where c.id = meetups.couple_id
               and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid()))
);

alter publication supabase_realtime add table public.meetups;

------------------------------------------------------------------------------
-- Attach the caller's selfie to the correct side (a/b) and auto-complete when
-- both sides are in. SECURITY DEFINER so the column choice + completion is
-- decided server-side (no client race over which side it is).
------------------------------------------------------------------------------

create or replace function public.set_meetup_selfie(p_meetup_id uuid, p_handle text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_couple uuid;
    v_is_a   boolean;
    v_a      text;
    v_b      text;
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    select m.couple_id,
           (c.user_a_id = auth.uid()),
           m.selfie_a_handle,
           m.selfie_b_handle
      into v_couple, v_is_a, v_a, v_b
      from public.meetups m
      join public.couples c on c.id = m.couple_id
     where m.id = p_meetup_id
       and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid());

    if v_couple is null then
        raise exception 'meetup_not_found';
    end if;

    if v_is_a then
        v_a := p_handle;
    else
        v_b := p_handle;
    end if;

    update public.meetups
       set selfie_a_handle = v_a,
           selfie_b_handle = v_b,
           status       = case when v_a is not null and v_b is not null
                               then 'completed' else status end,
           completed_at = case when v_a is not null and v_b is not null
                               then now() else completed_at end
     where id = p_meetup_id;
end $$;

revoke all on function public.set_meetup_selfie(uuid, text) from public;
grant execute on function public.set_meetup_selfie(uuid, text) to authenticated;
