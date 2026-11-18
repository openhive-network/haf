-- haf_block_explorer's per-database grants for its tavern-mock gate step
-- (hafbe#208), applied by serve.sh as postgres in haf_template on every start
-- (idempotent), so every clone carries them. The step loads CI's mock blocks
-- (91000001 and up) as hafbe's tests/mocks/install_mock_data.sh does, which
-- writes hafd tables owned by hived_group through no SECURITY DEFINER path, and
-- the consumer holds no grant option on them, so nobody in a clone could grant
-- this. They reach only the per-run clones made from haf_template, never
-- haf_block_log or any other database.

grant insert on hafd.blocks, hafd.operations to haf_shared_consumer;
grant update on hafd.hive_state to haf_shared_consumer;
