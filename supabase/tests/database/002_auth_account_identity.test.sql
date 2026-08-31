begin;

select plan(44);

select has_table('public', 'profiles', 'profiles exists');
select has_table('public', 'fantasy_accounts', 'fantasy_accounts exists');
select has_table(
  'public',
  'user_fantasy_accounts',
  'user_fantasy_accounts exists'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'profiles has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.fantasy_accounts'::regclass
  ),
  'fantasy_accounts has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.user_fantasy_accounts'::regclass
  ),
  'user_fantasy_accounts has RLS enabled'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.fantasy_accounts'::regclass
      and conname = 'fantasy_accounts_provider_external_user_id_key'
      and contype = 'u'
  ),
  'provider and external user ID form a unique identity'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.user_fantasy_accounts'::regclass
      and conname = 'user_fantasy_accounts_user_account_key'
      and contype = 'u'
  ),
  'a user cannot link the same fantasy account twice'
);
select has_index(
  'public',
  'user_fantasy_accounts',
  'user_fantasy_accounts_account_user_idx',
  'fantasy-account authorization lookup is indexed'
);
select has_index(
  'public',
  'user_fantasy_accounts',
  'user_fantasy_accounts_one_primary_per_user_idx',
  'primary-account lookup is indexed and unique'
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
    '10000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'alice@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"  Alice  ","avatar_url":"  https://example.test/alice.png  "}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'bob@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"   ","avatar_url":"   "}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

select is(
  (select count(*)::integer from public.profiles),
  2,
  'inserting Auth users creates one profile each'
);
select results_eq(
  $$
    select display_name, avatar_url
    from public.profiles
    where id = '10000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('Alice'::text, 'https://example.test/alice.png'::text) $$,
  'safe profile metadata is trimmed and copied'
);
select results_eq(
  $$
    select display_name, avatar_url
    from public.profiles
    where id = '10000000-0000-0000-0000-000000000002'
  $$,
  $$ values (null::text, null::text) $$,
  'blank profile metadata is stored as null'
);

insert into public.profiles (id, display_name, avatar_url)
select
  users.id,
  null,
  null
from auth.users as users
on conflict (id) do nothing;

select is(
  (select count(*)::integer from public.profiles),
  2,
  'profile backfill is idempotent'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values (
  '00000000-0000-0000-0000-000000000000',
  '10000000-0000-0000-0000-000000000003',
  'authenticated',
  'authenticated',
  'cascade@example.test',
  '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now(),
  '',
  '',
  '',
  ''
);
delete from auth.users
where id = '10000000-0000-0000-0000-000000000003';

select is(
  (
    select count(*)::integer
    from public.profiles
    where id = '10000000-0000-0000-0000-000000000003'
  ),
  0,
  'deleting an Auth user cascades to the profile'
);

insert into public.fantasy_accounts (
  id,
  provider,
  external_user_id,
  username,
  normalized_username,
  display_name
)
values
  (
    '20000000-0000-0000-0000-000000000001',
    'sleeper',
    'sleeper-user-1',
    'MutableName',
    'mutablename',
    'Shared account'
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    'sleeper',
    'sleeper-user-2',
    'MutableName',
    'mutablename',
    'Unlinked account'
  );

insert into public.user_fantasy_accounts (
  id,
  user_id,
  fantasy_account_id,
  label,
  is_primary
)
values
  (
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'Main',
    true
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    null,
    true
  );

select is(
  (
    select count(*)::integer
    from public.user_fantasy_accounts
    where fantasy_account_id = '20000000-0000-0000-0000-000000000001'
  ),
  2,
  'two app users can reference one shared fantasy account'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_accounts
    where username = 'MutableName'
  ),
  2,
  'username is not a canonical unique key'
);
select throws_ok(
  $$
    insert into public.user_fantasy_accounts (user_id, fantasy_account_id)
    values (
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  null,
  'duplicate user/account links are rejected'
);
select throws_ok(
  $$
    insert into public.user_fantasy_accounts (
      user_id,
      fantasy_account_id,
      is_primary
    )
    values (
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000002',
      true
    )
  $$,
  '23505',
  null,
  'a user cannot have two primary fantasy accounts'
);
select throws_ok(
  $$
    insert into public.fantasy_accounts (
      provider,
      external_user_id,
      username,
      normalized_username
    )
    values ('sleeper', 'sleeper-user-1', 'AnotherName', 'anothername')
  $$,
  '23505',
  null,
  'duplicate provider/external-user identities are rejected'
);

select ok(
  (
    select proconfig @> array['search_path=pg_catalog']
    from pg_proc
    where oid = 'app_private.set_updated_at()'::regprocedure
  ),
  'updated-at trigger function has a fixed safe search path'
);
select ok(
  (
    select proconfig @> array['search_path=pg_catalog']
    from pg_proc
    where oid = 'app_private.create_profile_for_new_user()'::regprocedure
  ),
  'profile trigger function has a fixed safe search path'
);
select is(
  has_function_privilege('anon', 'app_private.set_updated_at()', 'execute'),
  false,
  'anon cannot execute the updated-at trigger function'
);
select is(
  has_function_privilege(
    'authenticated',
    'app_private.set_updated_at()',
    'execute'
  ),
  false,
  'authenticated cannot execute the updated-at trigger function'
);
select ok(
  not exists (
    select 1
    from pg_proc
    cross join lateral aclexplode(proacl) as acl
    where oid = 'app_private.set_updated_at()'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute the updated-at trigger function'
);
select is(
  has_function_privilege(
    'anon',
    'app_private.create_profile_for_new_user()',
    'execute'
  ),
  false,
  'anon cannot execute the profile trigger function'
);
select is(
  has_function_privilege(
    'authenticated',
    'app_private.create_profile_for_new_user()',
    'execute'
  ),
  false,
  'authenticated cannot execute the profile trigger function'
);
select ok(
  not exists (
    select 1
    from pg_proc
    cross join lateral aclexplode(proacl) as acl
    where oid = 'app_private.create_profile_for_new_user()'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute the profile trigger function'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select count(*)::integer from public.profiles),
  1,
  'User A can read only their own profile'
);
select is(
  (
    select count(*)::integer
    from public.profiles
    where id = '10000000-0000-0000-0000-000000000002'
  ),
  0,
  'User A cannot read User B profile'
);
select results_eq(
  $$
    update public.profiles
    set display_name = 'Alice Updated'
    where id = '10000000-0000-0000-0000-000000000001'
    returning display_name
  $$,
  $$ values ('Alice Updated'::text) $$,
  'User A can update their own profile'
);
select is_empty(
  $$
    update public.profiles
    set display_name = 'Not allowed'
    where id = '10000000-0000-0000-0000-000000000002'
    returning id
  $$,
  'User A cannot update User B profile'
);
select throws_ok(
  $$
    insert into public.profiles (id, display_name)
    values ('10000000-0000-0000-0000-000000000002', 'Duplicate')
  $$,
  '42501',
  null,
  'User A cannot insert a profile directly'
);
select throws_ok(
  $$
    delete from public.profiles
    where id = '10000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'User A cannot delete a profile'
);

select is(
  (
    select count(*)::integer
    from public.fantasy_accounts
    where id = '20000000-0000-0000-0000-000000000001'
  ),
  1,
  'User A can read a linked fantasy account'
);
select is(
  (
    select count(*)::integer
    from public.fantasy_accounts
    where id = '20000000-0000-0000-0000-000000000002'
  ),
  0,
  'User A cannot read an unlinked fantasy account'
);
select throws_ok(
  $$
    insert into public.fantasy_accounts (
      provider,
      external_user_id,
      username,
      normalized_username
    )
    values ('sleeper', 'blocked', 'Blocked', 'blocked')
  $$,
  '42501',
  null,
  'User A cannot insert shared fantasy accounts'
);
select throws_ok(
  $$
    update public.fantasy_accounts
    set display_name = 'Blocked'
    where id = '20000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'User A cannot update shared fantasy accounts'
);
select throws_ok(
  $$
    delete from public.fantasy_accounts
    where id = '20000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'User A cannot delete shared fantasy accounts'
);

select is(
  (select count(*)::integer from public.user_fantasy_accounts),
  1,
  'User A can read their own link rows'
);
select is(
  (
    select count(*)::integer
    from public.user_fantasy_accounts
    where user_id = '10000000-0000-0000-0000-000000000002'
  ),
  0,
  'User A cannot read User B link rows'
);
select throws_ok(
  $$
    insert into public.user_fantasy_accounts (user_id, fantasy_account_id)
    values (
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000002'
    )
  $$,
  '42501',
  null,
  'User A cannot insert fantasy-account links'
);
select throws_ok(
  $$
    update public.user_fantasy_accounts
    set label = 'Blocked'
    where id = '30000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'User A cannot update fantasy-account links'
);
select throws_ok(
  $$
    delete from public.user_fantasy_accounts
    where id = '30000000-0000-0000-0000-000000000001'
  $$,
  '42501',
  null,
  'User A cannot delete fantasy-account links'
);

select * from finish();

rollback;
