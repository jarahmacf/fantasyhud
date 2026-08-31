begin;

select plan(7);

select has_table('auth', 'users', 'auth.users exists');
select has_schema('app_private', 'app_private exists');

select is(
  coalesce(
    (
      select bool_or(acl.privilege_type = 'CREATE')
      from pg_namespace as namespace
      cross join lateral aclexplode(namespace.nspacl) as acl
      where namespace.nspname = 'public'
        and acl.grantee = 0
    ),
    false
  ),
  false,
  'PUBLIC cannot create in public'
);

select is(
  has_schema_privilege('anon', 'app_private', 'USAGE'),
  false,
  'anon has no usage on app_private'
);

select is(
  has_schema_privilege('authenticated', 'app_private', 'USAGE'),
  false,
  'authenticated has no usage on app_private'
);

select ok(
  has_schema_privilege('service_role', 'app_private', 'USAGE'),
  'service_role has usage on app_private'
);

select ok(
  has_schema_privilege('postgres', 'app_private', 'USAGE'),
  'postgres has usage on app_private'
);

select * from finish();

rollback;
