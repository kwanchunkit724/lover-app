-- Phase 5 — IG-style chat features.
--
-- Adds: reply, reactions, edit, unsend (soft delete), vanish mode, read receipts.
--
-- Design notes:
--   * Reply: messages.reply_to_id → messages.id. Client renders the original
--     ciphertext preview by looking up the row (RLS already gates by couple).
--   * Edit: messages.edited_at set when ciphertext_b64 is replaced. Sender-only.
--   * Unsend: soft-delete via deleted_at. Row stays so reply chains don't break.
--     Clients render "已撤回" placeholder.
--   * Vanish mode: couples.vanish_mode boolean. When true, INSERT trigger sets
--     expires_at = now() + 24h. A pg_cron job (separate migration if cron OK)
--     can hard-delete expired rows. For v1 we just hide them client-side.
--   * Read receipts: messages.read_at set by recipient via RPC. Single bool
--     per message (couples app: only one recipient).
--   * Reactions: separate table to allow multi-emoji per message.

------------------------------------------------------------------------------
-- 1. messages — new columns

alter table public.messages
    add column if not exists reply_to_id uuid references public.messages(id) on delete set null,
    add column if not exists edited_at   timestamptz,
    add column if not exists deleted_at  timestamptz,
    add column if not exists expires_at  timestamptz,
    add column if not exists read_at     timestamptz;

create index if not exists messages_reply_to_idx on public.messages(reply_to_id);
create index if not exists messages_expires_idx  on public.messages(expires_at) where expires_at is not null;

------------------------------------------------------------------------------
-- 2. messages — UPDATE policy (sender can edit/unsend own; recipient can mark read)

create policy messages_update_sender on public.messages for update using (
    sender_id = auth.uid()
) with check (
    sender_id = auth.uid()
);

create policy messages_update_read_receipt on public.messages for update using (
    sender_id <> auth.uid()
    and exists (
        select 1 from public.couples c
         where c.id = messages.couple_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
) with check (
    sender_id <> auth.uid()
);

------------------------------------------------------------------------------
-- 3. couples.vanish_mode

alter table public.couples
    add column if not exists vanish_mode boolean not null default false;

------------------------------------------------------------------------------
-- 4. Vanish mode trigger — set expires_at on INSERT when couple is in vanish

create or replace function public.apply_vanish_mode()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  vm boolean;
begin
  select vanish_mode into vm from public.couples where id = new.couple_id;
  if vm then
    new.expires_at := now() + interval '24 hours';
  end if;
  return new;
end;
$$;

drop trigger if exists messages_vanish_trigger on public.messages;
create trigger messages_vanish_trigger
  before insert on public.messages
  for each row execute function public.apply_vanish_mode();

------------------------------------------------------------------------------
-- 5. message_reactions

create table if not exists public.message_reactions (
    message_id  uuid not null references public.messages(id) on delete cascade,
    user_id     uuid not null references public.users(id)    on delete cascade,
    emoji       text not null check (length(emoji) between 1 and 16),
    created_at  timestamptz not null default now(),
    primary key (message_id, user_id, emoji)
);

create index if not exists message_reactions_message_idx on public.message_reactions(message_id);

alter table public.message_reactions enable row level security;

-- SELECT: any couple member of the underlying message
create policy reactions_select_member on public.message_reactions for select using (
    exists (
        select 1
          from public.messages m
          join public.couples  c on c.id = m.couple_id
         where m.id = message_reactions.message_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

-- INSERT: only as self, only on a message in your couple
create policy reactions_insert_self on public.message_reactions for insert with check (
    user_id = auth.uid()
    and exists (
        select 1
          from public.messages m
          join public.couples  c on c.id = m.couple_id
         where m.id = message_reactions.message_id
           and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
    )
);

-- DELETE: only your own reactions
create policy reactions_delete_self on public.message_reactions for delete using (
    user_id = auth.uid()
);

------------------------------------------------------------------------------
-- 6. RPCs

-- Mark message as read (recipient only)
create or replace function public.mark_message_read(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.messages
     set read_at = coalesce(read_at, now())
   where id = p_message_id
     and sender_id <> auth.uid()
     and read_at is null
     and exists (
       select 1 from public.couples c
        where c.id = messages.couple_id
          and (c.user_a_id = auth.uid() or c.user_b_id = auth.uid())
     );
end;
$$;

grant execute on function public.mark_message_read(uuid) to authenticated;

-- Toggle vanish mode for the caller's couple
create or replace function public.set_vanish_mode(p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.couples
     set vanish_mode = p_enabled
   where user_a_id = auth.uid() or user_b_id = auth.uid();
end;
$$;

grant execute on function public.set_vanish_mode(boolean) to authenticated;

------------------------------------------------------------------------------
-- 7. Realtime — add reactions to publication

alter publication supabase_realtime add table public.message_reactions;
