/*
Overrides hive.get_estimated_hive_head_block() for tests and lets you steer its result.

Install:
  SELECT test.install_mock_hive_get_estimated_hive_head_block();
Set/read:
  SELECT test.set_head_block_num(123);
  SELECT hive.get_estimated_hive_head_block();
*/


CREATE OR REPLACE FUNCTION test.install_mock_hive_get_estimated_hive_head_block()
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
AS
$$
BEGIN
    EXECUTE 'CREATE TABLE IF NOT EXISTS test.head_block( num INTEGER )';

    EXECUTE 'GRANT USAGE ON SCHEMA test TO PUBLIC';
    EXECUTE 'GRANT ALL PRIVILEGES ON TABLE test.head_block TO PUBLIC';

    EXECUTE
        'INSERT INTO test.head_block(num)
         SELECT 50
         WHERE NOT EXISTS (SELECT 1 FROM test.head_block)';

    EXECUTE
        'CREATE OR REPLACE FUNCTION hive.get_estimated_hive_head_block()
            RETURNS INTEGER
            LANGUAGE plpgsql
            STABLE
         AS
         $fn$
         DECLARE
           __result INTEGER;
         BEGIN
           SELECT num INTO __result FROM test.head_block;
           RETURN __result;
         END;
         $fn$;';

    EXECUTE 'GRANT EXECUTE ON FUNCTION hive.get_estimated_hive_head_block() TO PUBLIC';

    EXECUTE
        'CREATE OR REPLACE FUNCTION test.set_head_block_num(_num INTEGER)
            RETURNS VOID
            LANGUAGE plpgsql
            VOLATILE
         AS
         $fn$
         BEGIN
           UPDATE test.head_block SET num = _num;
         END;
         $fn$;';

    EXECUTE 'GRANT EXECUTE ON FUNCTION test.set_head_block_num(INTEGER) TO PUBLIC';
END;
$$;
