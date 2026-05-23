-- v1.6.0 — Track when an entry was last edited.
--
-- Entries are now editable after creation (user can come back the day
-- after an event and add the cover photo / reflection / tweaks). We want
-- updated_at so:
--   • the calendar / detail UI can show "edited just now" hints later,
--   • realtime UPDATE events can be filtered/ordered deterministically,
--   • storage GC can prune orphan covers from edits that swapped photos.
--
-- Trigger keeps the column fresh on any UPDATE. INSERT defaults updated_at
-- to created_at via the column default (now()).
--
-- Also widens RLS: existing 0008_entries.sql only granted select / insert /
-- delete to couple members. Add an UPDATE policy with the same membership
-- check so either partner can edit the shared entry.

alter table public.entries
    add column if not exists updated_at timestamptz not null default now();

create or replace function public.touch_entries_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists entries_set_updated_at on public.entries;
create trigger entries_set_updated_at
    before update on public.entries
    for each row
    execute function public.touch_entries_updated_at();

drop policy if exists entries_update_member on public.entries;
create policy entries_update_member on public.entries for update using (
    exists (
        select 1 from public.couples c
         where c.id = entries.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
) with check (
    exists (
        select 1 from public.couples c
         where c.id = entries.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);
