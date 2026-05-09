-- v1.3.4 — allow the 'cream' theme on the users.theme_id CHECK constraint.
--
-- v1.2.1 added Theme.cream (Cream × Ink, the new default that matches the
-- v1.1.1 app icon palette). The original CHECK constraint only listed
-- ('jbeam','notion','cozy'), so any first-time sign-in upserting a row
-- with theme_id='cream' failed with:
--   ERROR: new row for relation "users" violates check constraint
--   "users_theme_id_check"
--
-- This was applied live via the Supabase SQL editor before the migration
-- file landed; the file is checked in for repo parity / fresh-clone
-- bootstrap.

alter table public.users drop constraint if exists users_theme_id_check;
alter table public.users
  add constraint users_theme_id_check
  check (theme_id in ('cream','jbeam','notion','cozy'));
