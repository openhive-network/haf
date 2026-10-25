-- haf_fyp's cluster-wide roles (its db/builtin_roles.sql), applied by serve.sh
-- as postgres on every start (idempotent). haf_fyp_user is deliberately in no
-- HAF group: haf_fyp's install asserts that it does not inherit
-- hive_applications_group. haf_fyp's install in a clone skips builtin_roles.sql
-- and runs as the consumer, a member of haf_fyp_owner.

do $$
begin
    create role haf_fyp_owner with login inherit in role hive_applications_owner_group;
exception when duplicate_object then
    null;
end
$$;

do $$
begin
    create role haf_fyp_user with login inherit;
exception when duplicate_object then
    null;
end
$$;

grant haf_fyp_user to haf_fyp_owner;
grant haf_fyp_owner to haf_shared_consumer;
grant haf_fyp_owner to haf_admin;
