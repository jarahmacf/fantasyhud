begin;

select plan(32);

select has_function(
  'public',
  'connect_sleeper_account',
  array['uuid', 'text', 'text', 'text', 'text', 'jsonb'],
  'Sleeper connection function exists'
);
select ok(
  (
    select procedure.prosecdef
    from pg_proc as procedure
    where procedure.oid = 'public.connect_sleeper_account(uuid,text,text,text,text,jsonb)'::regprocedure
  ),
  'Sleeper connection function is SECURITY DEFINER'
);
select ok(
  (
    select procedure.proconfig @> array['search_path=pg_catalog']
    from pg_proc as procedure
    where procedure.oid = 'public.connect_sleeper_account(uuid,text,text,text,text,jsonb)'::regprocedure
  ),
  'Sleeper connection function has a fixed safe search path'
);
select ok(
  not exists (
    select 1
    from pg_proc as procedure
    cross join lateral aclexplode(procedure.proacl) as acl
    where procedure.oid = 'public.connect_sleeper_account(uuid,text,text,text,text,jsonb)'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute the Sleeper connection function'
);
select is(
  has_function_privilege(
    'anon',
    'public.connect_sleeper_account(uuid,text,text,text,text,jsonb)',
    'execute'
  ),
  false,
  'anon cannot execute the Sleeper connection function'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.connect_sleeper_account(uuid,text,text,text,text,jsonb)',
    'execute'
  ),
  false,
  'authenticated cannot execute the Sleeper connection function'
);
select is(
  has_function_privilege(
    'service_role',
    'public.connect_sleeper_account(uuid,text,text,text,text,jsonb)',
    'execute'
  ),
  true,
  'service_role can execute the Sleeper connection function'
);
select is(
  has_function_privilege(
    'postgres',
    'public.connect_sleeper_account(uuid,text,text,text,text,jsonb)',
    'execute'
  ),
  true,
  'postgres can execute the Sleeper connection function'
);

select throws_ok(
  $$
    select *
    from public.connect_sleeper_account(
      '40000000-0000-0000-0000-000000000099',
      'missing-user',
      'MissingUser',
      '',
      '',
      '{}'::jsonb
    )
  $$,
  '22023',
  'A valid app user is required.',
  'the function rejects an unknown Auth user'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '40000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'task004-a@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '40000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'task004-b@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

create temporary table first_connection as
select *
from public.connect_sleeper_account(
  '40000000-0000-0000-0000-000000000001',
  '900719925474099312345',
  'CanonicalUser',
  'Canonical Display',
  'https://sleepercdn.com/avatars/old-avatar',
  '{"avatar_id":"old-avatar"}'::jsonb
);

select is(
  (
    select count(*)::integer
    from public.fantasy_accounts
    where provider = 'sleeper'
      and external_user_id = '900719925474099312345'
  ),
  1,
  'the first call creates one shared Sleeper account'
);
select is(
  (
    select count(*)::integer
    from public.user_fantasy_accounts
    where user_id = '40000000-0000-0000-0000-000000000001'
  ),
  1,
  'the first call creates one app-user link'
);
select results_eq(
  $$ select is_primary, created_link from first_connection $$,
  $$ values (true, true) $$,
  'the first connection is primary and reports a newly created link'
);
select is(
  (
    select provider
    from public.fantasy_accounts
    where id = (select fantasy_account_id from first_connection)
  ),
  'sleeper',
  'the provider is exactly sleeper'
);
select is(
  (
    select external_user_id
    from public.fantasy_accounts
    where id = (select fantasy_account_id from first_connection)
  ),
  '900719925474099312345',
  'the canonical external user ID remains exact text'
);
select results_eq(
  $$
    select username, normalized_username
    from public.fantasy_accounts
    where id = (select fantasy_account_id from first_connection)
  $$,
  $$ values ('CanonicalUser'::text, 'canonicaluser'::text) $$,
  'the canonical username is stored and normalized'
);
select is(
  (
    select last_synced_at
    from public.fantasy_accounts
    where id = (select fantasy_account_id from first_connection)
  ),
  null::timestamptz,
  'identity resolution does not set last_synced_at'
);
select is(
  (
    select jsonb_typeof(provider_metadata)
    from public.fantasy_accounts
    where id = (select fantasy_account_id from first_connection)
  ),
  'object',
  'provider metadata remains a JSON object'
);

create temporary table account_before_repeat as
select id, created_at, last_synced_at
from public.fantasy_accounts
where id = (select fantasy_account_id from first_connection);

create temporary table repeated_connection as
select *
from public.connect_sleeper_account(
  '40000000-0000-0000-0000-000000000001',
  '900719925474099312345',
  'CanonicalUser',
  'Canonical Display',
  'https://sleepercdn.com/avatars/old-avatar',
  '{"avatar_id":"old-avatar"}'::jsonb
);

select is(
  (
    select count(*)::integer
    from public.fantasy_accounts
    where provider = 'sleeper'
      and external_user_id = '900719925474099312345'
  ),
  1,
  'repeating the call creates no second fantasy account'
);
select is(
  (
    select count(*)::integer
    from public.user_fantasy_accounts
    where user_id = '40000000-0000-0000-0000-000000000001'
  ),
  1,
  'repeating the call creates no second link'
);
select results_eq(
  $$
    select fantasy_account_id, user_fantasy_account_id
    from repeated_connection
  $$,
  $$
    select fantasy_account_id, user_fantasy_account_id
    from first_connection
  $$,
  'repeating the call returns the same account and link IDs'
);
select results_eq(
  $$ select is_primary, created_link from repeated_connection $$,
  $$ values (true, false) $$,
  'repeating the call preserves primary and reports a reused link'
);

update public.user_fantasy_accounts
set label = 'My tracked account'
where id = (select user_fantasy_account_id from first_connection);

create temporary table renamed_connection as
select *
from public.connect_sleeper_account(
  '40000000-0000-0000-0000-000000000001',
  '900719925474099312345',
  'RenamedCanonicalUser',
  'Renamed Display',
  'https://sleepercdn.com/avatars/new-avatar',
  '{"avatar_id":"new-avatar"}'::jsonb
);

select results_eq(
  $$
    select username, normalized_username, display_name, provider_metadata
    from public.fantasy_accounts
    where id = (select fantasy_account_id from first_connection)
  $$,
  $$
    values (
      'RenamedCanonicalUser'::text,
      'renamedcanonicaluser'::text,
      'Renamed Display'::text,
      '{"avatar_id":"new-avatar"}'::jsonb
    )
  $$,
  'mutable provider fields update for the same canonical external ID'
);
select is(
  (
    select external_user_id
    from public.fantasy_accounts
    where id = (select fantasy_account_id from renamed_connection)
  ),
  '900719925474099312345',
  'a username change does not change canonical identity'
);
select is(
  (
    select label
    from public.user_fantasy_accounts
    where id = (select user_fantasy_account_id from renamed_connection)
  ),
  'My tracked account',
  'reconnecting preserves the existing link label'
);
select results_eq(
  $$
    select account.created_at, account.last_synced_at
    from public.fantasy_accounts as account
    where account.id = (select fantasy_account_id from renamed_connection)
  $$,
  $$ select created_at, last_synced_at from account_before_repeat $$,
  'provider refresh preserves created_at and last_synced_at'
);

create temporary table second_user_connection as
select *
from public.connect_sleeper_account(
  '40000000-0000-0000-0000-000000000002',
  '900719925474099312345',
  'RenamedCanonicalUser',
  'Renamed Display',
  'https://sleepercdn.com/avatars/new-avatar',
  '{"avatar_id":"new-avatar"}'::jsonb
);

select is(
  (
    select count(*)::integer
    from public.fantasy_accounts
    where provider = 'sleeper'
      and external_user_id = '900719925474099312345'
  ),
  1,
  'a second app user reuses the shared canonical account'
);
select is(
  (
    select count(*)::integer
    from public.user_fantasy_accounts
    where fantasy_account_id = (select fantasy_account_id from first_connection)
  ),
  2,
  'the second app user receives a separate link'
);
select results_eq(
  $$ select is_primary, created_link from second_user_connection $$,
  $$ values (true, true) $$,
  'the second app user receives their own primary link'
);
select results_eq(
  $$
    select label, is_primary
    from public.user_fantasy_accounts
    where id = (select user_fantasy_account_id from first_connection)
  $$,
  $$ values ('My tracked account'::text, true) $$,
  'the first app user link remains untouched'
);

create temporary table additional_connection as
select *
from public.connect_sleeper_account(
  '40000000-0000-0000-0000-000000000001',
  'another-canonical-user-id',
  'AnotherCanonicalUser',
  '',
  '',
  '{}'::jsonb
);

select results_eq(
  $$ select is_primary, created_link from additional_connection $$,
  $$ values (false, true) $$,
  'a later canonical account link is created without becoming primary'
);
select is(
  (
    select count(*)::integer
    from public.user_fantasy_accounts
    where user_id = '40000000-0000-0000-0000-000000000001'
      and is_primary
  ),
  1,
  'an app user still has exactly one primary link'
);
select is(
  (
    select count(*)::integer
    from public.user_fantasy_accounts
    where user_id = '40000000-0000-0000-0000-000000000001'
  ),
  2,
  'the partial unique primary index remains valid with two links'
);

select * from finish();

rollback;
