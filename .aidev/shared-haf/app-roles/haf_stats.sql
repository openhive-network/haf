-- haf_stats' cluster-wide roles (its db/builtin_roles.sql), applied by serve.sh
-- as postgres on every start (idempotent). haf_stats_user is NOINHERIT and in no
-- HAF group; haf_stats grants it its hafd and hive reads directly, per database,
-- in its install. haf_stats' install in a clone skips the role creation and
-- runs as the consumer, a member of haf_stats_owner.

do $$
begin
    create role haf_stats_owner with login inherit in role hive_applications_owner_group;
exception when duplicate_object then
    null;
end
$$;

do $$
begin
    create role haf_stats_user with login noinherit;
exception when duplicate_object then
    null;
end
$$;

alter role haf_stats_user set statement_timeout = '30s';

grant haf_stats_user to haf_stats_owner;
grant haf_stats_owner to haf_shared_consumer;
grant haf_stats_owner to haf_admin;
