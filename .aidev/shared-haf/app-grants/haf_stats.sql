-- haf_stats' per-database grants (the hafd/hive block of its
-- db/builtin_roles.sql), applied by serve.sh as postgres in haf_template on
-- every start (idempotent), so every clone carries them. haf_stats_user is
-- NOINHERIT and in no HAF group, and the consumer holds no grant option on
-- these schemas, so nobody in a clone could grant them.

grant usage on schema hafd to haf_stats_owner, haf_stats_user;
grant select on all tables in schema hafd to haf_stats_owner, haf_stats_user;

grant usage on schema hive to haf_stats_owner, haf_stats_user;
grant select on all tables in schema hive to haf_stats_owner, haf_stats_user;
grant execute on all functions in schema hive to haf_stats_owner, haf_stats_user;
