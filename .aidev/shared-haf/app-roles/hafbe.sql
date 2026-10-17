-- haf_block_explorer's cluster-wide roles (its db/builtin_roles.sql), applied by
-- serve.sh as postgres on every start (idempotent). They are members of the
-- balance_tracker, reputation_tracker and HAfAH roles, so serve.sh applies
-- btracker.sql, reptracker.sql and hafah.sql first. haf_block_explorer's install
-- in a clone skips the builtin_roles.sql of all three apps and runs as the
-- consumer, a member of hafbe_owner, btracker_owner and reptracker_owner.

do $$
begin
    create role hafbe_owner with login inherit in role hive_applications_owner_group, reptracker_owner, btracker_owner;
exception when duplicate_object then
    null;
end
$$;

do $$
begin
    create role hafbe_user with login inherit in role hive_applications_group, reptracker_user, btracker_user;
exception when duplicate_object then
    null;
end
$$;

alter role hafbe_user set statement_timeout = '10s';

grant hafah_owner to hafbe_owner;
grant hafah_user to hafbe_user;
grant hafbe_user to hafbe_owner;
grant hafbe_owner to haf_shared_consumer;
grant hafbe_owner to haf_admin;
