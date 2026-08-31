create extension if not exists pgtap with schema extensions;

create schema if not exists app_private;

comment on schema app_private is
  'Reserved for future server-only functions and internal database objects.';

revoke all on schema app_private from public, anon, authenticated;
grant usage on schema app_private to service_role, postgres;

revoke create on schema public from public;
