DROP SCHEMA IF EXISTS cab_app CASCADE;

CREATE SCHEMA IF NOT EXISTS cab_app;

CREATE OR REPLACE FUNCTION cab_app.define_schema ()
  RETURNS VOID
  LANGUAGE 'plpgsql'
  AS $$
BEGIN
  RAISE NOTICE 'Attempting to create an application schema tables...';
  CREATE TABLE IF NOT EXISTS cab_app.app_status (
    continue_processing boolean NOT NULL,
    last_processed_block int NOT NULL
  );

  INSERT INTO cab_app.app_status (continue_processing, last_processed_block)
  VALUES (TRUE, 0);

  RAISE NOTICE 'hive.cabc = %', json_agg(t)
    FROM (
      SELECT
        *
      FROM
        hive.cabc) t;


-- -- A dummy table to make this application the forking application
--   CREATE TABLE IF NOT EXISTS cab_app.dummy_table( )
--   INHERITS (
--     hive.cabc
--   );
END
$$;

--- Helper function telling application main-loop to continue execution.
CREATE OR REPLACE FUNCTION cab_app.continueProcessing ()
  RETURNS boolean
  LANGUAGE 'plpgsql'
  AS $$
BEGIN
  RETURN continue_processing
FROM
  cab_app.app_status
LIMIT 1;
END
$$;

CREATE OR REPLACE FUNCTION cab_app.allowProcessing ()
  RETURNS VOID
  LANGUAGE 'plpgsql'
  AS $$
BEGIN
  UPDATE
    cab_app.app_status
  SET
    continue_processing = TRUE;
END
$$;

--- Helper function to be called from separate transaction (must be committed) to safely stop execution of the application.
CREATE OR REPLACE FUNCTION cab_app.stopProcessing ()
  RETURNS VOID
  LANGUAGE 'plpgsql'
  AS $$
BEGIN
  UPDATE
    cab_app.app_status
  SET
    continue_processing = FALSE;
END
$$;

CREATE OR REPLACE FUNCTION cab_app.storeLastProcessedBlock (IN _lastBlock int)
  RETURNS VOID
  LANGUAGE 'plpgsql'
  AS $$
BEGIN
  UPDATE
    cab_app.app_status
  SET
    last_processed_block = _lastBlock;
END
$$;

CREATE OR REPLACE FUNCTION cab_app.lastProcessedBlock ()
  RETURNS int
  LANGUAGE 'plpgsql'
  AS $$
BEGIN
  RETURN last_processed_block
  FROM cab_app.app_status
  LIMIT 1;
END
$$;

CREATE OR REPLACE FUNCTION cab_app.process_block_range_data_c (IN _appContext varchar, IN _from int, IN _to int, IN _report_step int = 1000)
  RETURNS VOID
  LANGUAGE 'plpgsql'
  AS $$
BEGIN
  PERFORM hive.app_state_providers_update (_from, _to, _appContext);
END
$$;

CREATE OR REPLACE PROCEDURE cab_app.do_massive_processing (IN _appContext varchar, IN _from int, IN _to int, IN _step int, INOUT _last_block int)
LANGUAGE 'plpgsql'
AS $$
BEGIN
  RAISE NOTICE 'Entering massive processing of block range: <%, %>...', _from, _to;
  RAISE NOTICE 'Detaching HAF application context...';
  PERFORM hive.app_context_detach (_appContext);
  --- You can do here also other things to speedup your app, i.e. disable constrains, remove indexes etc.
  FOR b IN _from.._to BY
    _step LOOP
      _last_block := b + _step - 1;
      IF _last_block > _to THEN
        --- in case the _step is larger than range length
        _last_block := _to;
      END IF;
      RAISE NOTICE 'Attempting to process a block range: <%, %>', b, _last_block;
      PERFORM cab_app.process_block_range_data_c (_appContext, b, _last_block);
      COMMIT;
      RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;
      EXIT
      WHEN NOT cab_app.continueProcessing ();
    END LOOP;
  IF cab_app.continueProcessing () AND _last_block < _to THEN
    RAISE NOTICE 'Attempting to process a block range (rest): <%, %>', b, _last_block;
    --- Supplement last part of range if anything left.
    PERFORM cab_app.process_block_range_data_c (_last_block, _to);
    _last_block := _to;
    COMMIT;
    RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;
  END IF;
  RAISE NOTICE 'Attaching HAF application context at block: %.', _last_block;
  PERFORM hive.app_context_attach (_appContext, _last_block);
  --- You should enable here all things previously disabled at begin of this function...
  RAISE NOTICE 'Leaving massive processing of block range: <%, %>...', _from, _to;
END
$$;

CREATE OR REPLACE PROCEDURE cab_app.processBlock (IN _appContext varchar, IN _block int)
LANGUAGE 'plpgsql'
AS $$
BEGIN
  PERFORM cab_app.process_block_range_data_c (_appContext, _block, _block);
  COMMIT;
  -- For single block processing we want to commit all changes for each one.
END
$$;


/** Application entry point, which:
 - defines its data schema,
 - creates HAF application context,
 - starts application main-loop (which iterates infinitely). To stop it call `cab_app.stopProcessing();` from another session and commit its trasaction.
 */
CREATE OR REPLACE PROCEDURE cab_app.main (IN _appContext varchar, IN _maxBlockLimit int = 0, IN _step int = 0, IN _consensus_storage TEXT = '/home/hived/datadir' )
LANGUAGE 'plpgsql'
AS $$
DECLARE
  __last_block int;
  __next_block_range hive.blocks_range;
  total_time_start timestamp;
  temp_time_start timestamp;
  temp_interval interval;
BEGIN
  CREATE TABLE IF NOT EXISTS cab_app.LOG_TABLE (
    first_block int,
    last_block int,
    time interval
  );
  total_time_start := clock_timestamp();
  IF NOT hive.app_context_exists (_appContext) THEN
    RAISE NOTICE 'Attempting to create a HAF application context...';
    PERFORM hive.app_create_context (_appContext);
    COMMIT;
    
    RAISE NOTICE 'all tables = %', json_agg(t)
      FROM (
        SELECT
          *
        FROM
          pg_catalog.pg_tables
        WHERE
          schemaname != 'pg_catalog'
          AND schemaname != 'information_schema') t;

    RAISE NOTICE 'Naprawde hive.contexts = %', json_agg(t)
      FROM (
        SELECT
          *
        FROM
          hive.contexts) t;

    PERFORM cab_app.define_schema ();
    PERFORM hive.app_state_provider_import ('KEYAUTH', _appContext);
    PERFORM hive.app_state_provider_import ('ACCOUNTS', _appContext);
    PERFORM hive.app_state_provider_import ('c_a_b_s_t', _appContext, _consensus_storage || '/' || _appContext);
    COMMIT;
  END IF;
  
  PERFORM cab_app.allowProcessing ();
  COMMIT;

  SELECT cab_app.lastProcessedBlock () INTO __last_block;
  
  RAISE NOTICE 'Last block processed by application: %', __last_block;
  
  IF NOT hive.app_context_is_attached (_appContext) THEN
    PERFORM hive.app_context_attach (_appContext, __last_block);
  END IF;
  
  RAISE NOTICE 'Entering application main loop...';

  WHILE cab_app.continueProcessing ()
    AND (_maxBlockLimit = 0
    OR __last_block < _maxBlockLimit)
  LOOP
      __next_block_range := hive.app_next_block (_appContext);
      IF __next_block_range IS NULL THEN
        RAISE WARNING 'Waiting for next block...';
        EXIT;
      ELSE
        IF _maxBlockLimit != 0 AND __next_block_range.first_block > _maxBlockLimit THEN
          __next_block_range.first_block := _maxBlockLimit;
        END IF;

        IF _maxBlockLimit != 0 AND __next_block_range.last_block > _maxBlockLimit THEN
          __next_block_range.last_block := _maxBlockLimit;
        END IF;

        RAISE NOTICE 'Attempting to process block range: <%,%>', __next_block_range.first_block, __next_block_range.last_block;

        IF __next_block_range.first_block != __next_block_range.last_block THEN
          temp_time_start = clock_timestamp();
          CALL cab_app.do_massive_processing (_appContext, __next_block_range.first_block, __next_block_range.last_block, _step, __last_block);
          temp_interval = clock_timestamp() - temp_time_start;
          INSERT INTO cab_app.LOG_TABLE
            VALUES (__next_block_range.first_block, __next_block_range.last_block, temp_interval);
          RAISE NOTICE 'Massive processing time = %', temp_interval;
        ELSE
          temp_time_start = clock_timestamp();
          CALL cab_app.processBlock (_appContext, __next_block_range.last_block);
          temp_interval = clock_timestamp() - temp_time_start;
          INSERT INTO cab_app.LOG_TABLE
            VALUES (__next_block_range.first_block, __next_block_range.last_block, temp_interval);
          RAISE NOTICE 'One block processing time = %', temp_interval;
          __last_block := __next_block_range.last_block;
        END IF;
      END IF;
    END LOOP;

  RAISE NOTICE 'Exiting application main loop at processed block: %.', __last_block;

  PERFORM cab_app.storeLastProcessedBlock (__last_block);
  COMMIT;
  
  IF hive.app_is_forking (_appContext) THEN
    RAISE NOTICE 'This is a forking Application';
  ELSE
    RAISE NOTICE 'This is a non-forking application';
  END IF;
  
  RAISE NOTICE 'Collected keys count=%', (
    SELECT
      json_agg(t)
    FROM (
      SELECT
        count(*)
      FROM
        hive.cabc_keyauth) t);
  
  PERFORM cab_app.display_stats ('Massive processing', 'WHERE last_block - first_block > 0');
  PERFORM cab_app.display_stats ('One block processing', 'WHERE last_block - first_block = 0');
  
  RAISE NOTICE 'Total time = %', clock_timestamp() - total_time_start;
END
$$;

CREATE OR REPLACE FUNCTION cab_app.display_stats (prefix varchar, condition varchar)
  RETURNS void
  LANGUAGE 'plpgsql'
  AS $$
DECLARE
  sum_time interval;
  count integer;
BEGIN
  EXECUTE format('SELECT SUM(time) FROM cab_app.log_table %s', condition) INTO sum_time;
  
  RAISE NOTICE '% sum time = %', prefix, sum_time;
  
  EXECUTE format('SELECT COUNT(*) FROM cab_app.log_table %s', condition) INTO count;
  
  RAISE NOTICE '%s count = %', prefix, count;
  
  IF count <> 0 THEN
    RAISE NOTICE '%s average time = %', prefix, sum_time / count;
  END IF;
END
$$;

