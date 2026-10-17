-- balance_tracker's cluster-wide roles (its db/builtin_roles.sql), applied by
-- serve.sh as postgres on every start (idempotent). haf_block_explorer installs
-- balance_tracker into its clone (schema hafbe_bal) as the consumer, a member of
-- btracker_owner, skipping builtin_roles.sql.

do $$
begin
    create role btracker_owner with login inherit in role hive_applications_owner_group;
exception when duplicate_object then
    null;
end
$$;

do $$
begin
    create role btracker_user with login inherit in role hive_applications_group;
exception when duplicate_object then
    null;
end
$$;

alter role btracker_user set statement_timeout = '10s';

grant btracker_user to btracker_owner;
grant btracker_owner to haf_shared_consumer;
grant btracker_owner to haf_admin;
