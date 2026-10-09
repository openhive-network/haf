-- HAfAH's cluster-wide roles (its db/builtin_roles.sql), applied by serve.sh as
-- postgres on every start (idempotent). The consumer cannot create roles, so
-- HAfAH's install in a clone skips builtin_roles.sql and runs as the consumer,
-- a member of hafah_owner, once it has granted CREATE, CONNECT on the clone to
-- both roles. The roles do not change between HAfAH versions, so every run
-- shares them.

do $$
begin
    create role hafah_owner with login inherit in role hive_applications_owner_group;
exception when duplicate_object then
    null;
end
$$;

do $$
begin
    create role hafah_user with login inherit in role hive_applications_group;
exception when duplicate_object then
    null;
end
$$;

alter role hafah_user set statement_timeout = '15s';

grant hafah_user to hafah_owner;
grant hafah_owner to haf_shared_consumer;
grant hafah_owner to haf_admin;
