-- Phase 3a — initial schema for the Us couples app.
--
-- Three tables:
--   users          — one row per Sign-in-with-Apple user, mirrors UserProfile
--   pairing_codes  — short-lived 6-digit handshake codes
--   couples        — one row per paired pair
--
-- Plus two SECURITY DEFINER RPCs:
--   create_pairing_code()                 — server-side code generation
--   redeem_pairing_code(code, anniv_iso)  — atomic anniversary cross-check + couple creation
--
-- Order matters: create all tables first, then RLS policies (some policies
-- reference other tables), then RPCs.

------------------------------------------------------------------------------
-- 1. TABLES
------------------------------------------------------------------------------

-- USERS: one row per signed-in Apple user. id = auth.users.id.
create table public.users (
    id              uuid primary key references auth.users(id) on delete cascade,
    my_name         text not null check (length(my_name) between 1 and 40),
    partner_name    text not null check (length(partner_name) between 1 and 40),
    anniversary_iso date not null,
    theme_id        text not null default 'jbeam' check (theme_id in ('jbeam','notion','cozy')),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at := now();
    return new;
end $$;

create trigger users_touch_updated_at
    before update on public.users
    for each row execute function public.touch_updated_at();

-- COUPLES: one row per paired pair. user_a_id < user_b_id by convention so
-- pairs are unique regardless of which side initiated.
create table public.couples (
    id          uuid primary key default gen_random_uuid(),
    user_a_id   uuid not null references public.users(id) on delete cascade,
    user_b_id   uuid not null references public.users(id) on delete cascade,
    paired_at   timestamptz not null default now(),
    constraint couples_distinct check (user_a_id <> user_b_id),
    constraint couples_ordered  check (user_a_id < user_b_id),
    constraint couples_unique   unique (user_a_id, user_b_id)
);

create index couples_user_a_idx on public.couples(user_a_id);
create index couples_user_b_idx on public.couples(user_b_id);

-- At-most-one couple per user via partial unique indexes on each side.
create unique index couples_one_per_user_a on public.couples(user_a_id);
create unique index couples_one_per_user_b on public.couples(user_b_id);

-- PAIRING CODES: 6-digit handshake codes that expire in 10 min.
create table public.pairing_codes (
    code            text primary key check (code ~ '^\d{6}$'),
    user_id         uuid not null unique references public.users(id) on delete cascade,
    anniversary_iso date not null,
    expires_at      timestamptz not null,
    created_at      timestamptz not null default now()
);

------------------------------------------------------------------------------
-- 2. ROW LEVEL SECURITY
------------------------------------------------------------------------------

alter table public.users         enable row level security;
alter table public.couples       enable row level security;
alter table public.pairing_codes enable row level security;

-- A user can read & update only their own row. Insert happens on signup.
create policy users_select_self on public.users for select using (id = auth.uid());
create policy users_update_self on public.users for update using (id = auth.uid()) with check (id = auth.uid());
create policy users_insert_self on public.users for insert with check (id = auth.uid());

-- Partners can read each other's row once paired (used to render partner_name
-- and theme_id on the Profile / chat headers).
create policy users_select_partner on public.users for select using (
    exists (
        select 1 from public.couples c
        where (c.user_a_id = auth.uid() and c.user_b_id = users.id)
           or (c.user_b_id = auth.uid() and c.user_a_id = users.id)
    )
);

-- A user can see only the couple row they're part of.
create policy couples_select_member on public.couples for select using (
    auth.uid() in (user_a_id, user_b_id)
);

-- No direct insert/update/delete on couples from clients — RPCs only.

-- Owner can read their own pairing code (UI shows "你嘅配對碼: 123456").
create policy pairing_codes_select_own on public.pairing_codes for select using (user_id = auth.uid());

-- No direct mutations of pairing_codes from clients — RPCs only.

------------------------------------------------------------------------------
-- 3. RPCs
------------------------------------------------------------------------------

-- create_pairing_code(): generate a fresh 6-digit code for the calling user,
-- replacing any existing code on conflict. Returns the code string.
create or replace function public.create_pairing_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    new_code text;
    me_anniv date;
    attempts int := 0;
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    if exists (select 1 from couples
                where user_a_id = auth.uid() or user_b_id = auth.uid()) then
        raise exception 'already_paired';
    end if;

    select anniversary_iso into me_anniv from users where id = auth.uid();
    if me_anniv is null then
        raise exception 'profile_missing';
    end if;

    loop
        new_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
        begin
            insert into pairing_codes (code, user_id, anniversary_iso, expires_at)
            values (new_code, auth.uid(), me_anniv, now() + interval '10 minutes')
            on conflict (user_id) do update
                set code = excluded.code,
                    anniversary_iso = excluded.anniversary_iso,
                    expires_at = excluded.expires_at,
                    created_at = now();
            return new_code;
        exception when unique_violation then
            attempts := attempts + 1;
            if attempts >= 5 then raise; end if;
        end;
    end loop;
end $$;

revoke all on function public.create_pairing_code() from public;
grant execute on function public.create_pairing_code() to authenticated;

-- redeem_pairing_code(code, anniversary_iso): atomic pair. Caller (B) provides
-- the code from A and their own anniversary. Both anniversaries must match
-- exactly. Creates the couple row, deletes the pairing code, returns couple id.
create or replace function public.redeem_pairing_code(
    p_code text,
    p_anniversary_iso date
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    pc          pairing_codes%rowtype;
    a_id        uuid;
    b_id        uuid := auth.uid();
    new_couple  uuid;
begin
    if b_id is null then
        raise exception 'not_authenticated';
    end if;

    if not exists (select 1 from users where id = b_id) then
        raise exception 'profile_missing';
    end if;

    select * into pc from pairing_codes where code = p_code;
    if not found then
        raise exception 'invalid_code';
    end if;

    if pc.expires_at < now() then
        delete from pairing_codes where code = p_code;
        raise exception 'code_expired';
    end if;

    if pc.user_id = b_id then
        raise exception 'cannot_pair_with_self';
    end if;

    if pc.anniversary_iso <> p_anniversary_iso then
        raise exception 'anniversary_mismatch';
    end if;

    a_id := pc.user_id;

    if exists (select 1 from couples
                where user_a_id in (a_id, b_id) or user_b_id in (a_id, b_id)) then
        raise exception 'already_paired';
    end if;

    insert into couples (user_a_id, user_b_id)
    values (least(a_id, b_id), greatest(a_id, b_id))
    returning id into new_couple;

    delete from pairing_codes where code = p_code;
    return new_couple;
end $$;

revoke all on function public.redeem_pairing_code(text, date) from public;
grant execute on function public.redeem_pairing_code(text, date) to authenticated;
