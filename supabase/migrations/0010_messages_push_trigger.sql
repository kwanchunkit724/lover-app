-- Push notifications: AFTER INSERT trigger on messages → calls the
-- send-push edge function via pg_net.
--
-- Why a SQL trigger instead of a Database Webhook?
--   The Supabase Dashboard's Webhooks integration was unavailable on the
--   free tier at setup time ("Integration not found"). pg_net achieves
--   the same outcome and is reproducible as a migration.
--
-- The send-push function has "Verify JWT with legacy secret" turned OFF
-- so this trigger does not need to forward an Authorization header. The
-- function still validates the webhook body shape before doing any work.

create extension if not exists pg_net;

create or replace function public.notify_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  payload jsonb;
begin
  payload := jsonb_build_object(
    'type',   'INSERT',
    'table',  'messages',
    'schema', 'public',
    'record', row_to_json(new)
  );

  perform net.http_post(
    url     := 'https://stzfhdjuiupejonyckdu.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body    := payload
  );

  return new;
end;
$$;

drop trigger if exists messages_push_trigger on public.messages;
create trigger messages_push_trigger
  after insert on public.messages
  for each row execute function public.notify_message_insert();
