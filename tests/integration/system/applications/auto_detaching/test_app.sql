SET ROLE haf_admin; 

DO
$$
BEGIN
  CREATE ROLE test_app_owner WITH LOGIN INHERIT IN ROLE hive_applications_group;

EXCEPTION WHEN duplicate_object THEN
  DROP OWNED BY test_app_owner  CASCADE;
  DROP ROLE test_app_owner;
  
  CREATE ROLE test_app_owner WITH LOGIN INHERIT IN ROLE hive_applications_group;
END
$$;

CREATE SCHEMA test_app AUTHORIZATION test_app_owner;

SET ROLE test_app_owner;

-- Some code performing actions by the app.
CREATE OR REPLACE PROCEDURE test_app.main(_appContext VARCHAR, _maxBlockLimit INT = NULL)
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __last_block INT := 0;
  __next_block_range hive.blocks_range;
  __block_range_len INT := 0;
BEGIN
  WHILE (_maxBlockLimit = 0 OR __last_block < _maxBlockLimit) LOOP
    __next_block_range := hive.app_next_block(_appContext);

    IF __next_block_range IS NULL THEN
       RAISE WARNING '% is waiting for next block...', _appContext;
    ELSE
      IF _maxBlockLimit != 0 and __next_block_range.first_block > _maxBlockLimit THEN
        __next_block_range.first_block  := _maxBlockLimit;
      END IF;

      IF _maxBlockLimit != 0 and __next_block_range.last_block > _maxBlockLimit THEN
        __next_block_range.last_block  := _maxBlockLimit;
      END IF;

      RAISE NOTICE '% is attempting to process block range: <%,%>', _appContext, __next_block_range.first_block, __next_block_range.last_block;
      __last_block := __next_block_range.last_block;
    END IF;
  END LOOP;

  RAISE NOTICE 'Exiting application main loop at processed block: %.', __last_block;
  
END
$$;

RESET ROLE;
