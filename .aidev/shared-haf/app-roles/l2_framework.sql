-- l2_framework's cluster-wide roles (its db/builtin_roles.sql), applied by
-- serve.sh as postgres on every start (idempotent). haf_block_explorer installs
-- l2_framework into its clone as the consumer, a member of l2_framework_owner,
-- skipping builtin_roles.sql.

do $$
begin
    create role l2_framework_owner with login inherit in role hive_applications_owner_group;
exception when duplicate_object then
    null;
end
$$;

do $$
begin
    create role l2_framework_user with login inherit in role hive_applications_group;
exception when duplicate_object then
    null;
end
$$;

grant l2_framework_user to l2_framework_owner;
grant l2_framework_owner to haf_shared_consumer;
grant l2_framework_owner to haf_admin;
