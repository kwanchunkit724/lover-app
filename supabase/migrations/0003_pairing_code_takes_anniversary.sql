-- Phase 3c follow-up — generator passes the anniversary they want to lock in
-- at code-creation time, instead of the RPC silently reading whatever was
-- saved during onboarding.
--
-- Why: users may have set a casual placeholder anniversary during onboarding
-- (or hit the timezone-shifted bug from v0.3.1), and they want an explicit
-- confirmation step before pairing. The new flow asks both phones to pick
-- the date deliberately — generator on the Generate screen, redeemer on the
-- Enter screen — and only then locks in.
--
-- Side effect: the anniversary stored in users.anniversary_iso (from
-- AuthService.upsertProfile) is no longer read by the RPC. It still lives in
-- the row for the Profile display, and a future phase may add a "edit your
-- anniversary" affordance.

-- Drop the old zero-arg version and replace with the new one-arg signature.
drop function if exists public.create_pairing_code();

create or replace function public.create_pairing_code(
    p_anniversary_iso date
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    new_code text;
    attempts int := 0;
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    if exists (select 1 from couples
                where user_a_id = auth.uid() or user_b_id = auth.uid()) then
        raise exception 'already_paired';
    end if;

    -- Caller must have a profile row (created at first sign-in via upsert).
    if not exists (select 1 from users where id = auth.uid()) then
        raise exception 'profile_missing';
    end if;

    loop
        new_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
        begin
            insert into pairing_codes (code, user_id, anniversary_iso, expires_at)
            values (new_code, auth.uid(), p_anniversary_iso, now() + interval '10 minutes')
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

revoke all on function public.create_pairing_code(date) from public;
grant execute on function public.create_pairing_code(date) to authenticated;
