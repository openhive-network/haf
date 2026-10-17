-- reputation_tracker's cluster-wide roles (its db/builtin_roles.sql), applied
-- by serve.sh as postgres on every start (idempotent). haf_block_explorer
-- installs reputation_tracker into its clone as the consumer, a member of
-- reptracker_owner, skipping builtin_roles.sql.

do $$
begin
    create role reptracker_owner with login inherit in role hive_applications_owner_group;
exception when duplicate_object then
    null;
end
$$;

do $$
begin
    create role reptracker_user with login inherit in role hive_applications_group;
exception when duplicate_object then
    null;
end
$$;

grant reptracker_user to reptracker_owner;
grant reptracker_owner to haf_shared_consumer;
grant reptracker_owner to haf_admin;
