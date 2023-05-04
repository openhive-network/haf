DROP SCHEMA IF EXISTS cab_app CASCADE;

CREATE SCHEMA IF NOT EXISTS cab_app;

/** Application entry point
 */
CREATE OR REPLACE PROCEDURE cab_app.main(
  IN _appContext VARCHAR,
  IN _maxBlockLimit INT = 0,
  IN _step INT = 0,
  IN _consensus_storage TEXT = '/home/hived/datadir/consensus_state_provider'
) LANGUAGE 'plpgsql' AS $$
DECLARE
  __from INT;
  __to INT;
  __last_block int;
  __next_block_range hive.blocks_range;
BEGIN
  CALL cab_app.prepare_app_data(_appContext, _consensus_storage, __last_block);
  
  RAISE NOTICE 'Entering application main loop...';

  WHILE cab_app.continue_processing() AND(_maxBlockLimit = 0 OR __last_block < _maxBlockLimit)
  LOOP
      __next_block_range := hive.app_next_block(_appContext);
      IF __next_block_range IS NULL THEN
        RAISE WARNING 'Waiting for next block...';
        EXIT;
      ELSE
        __from = __next_block_range.first_block;
        __to = __next_block_range.last_block;

        CALL cab_app.adjust_block_range(__from , __to , _maxBlockLimit);

        RAISE NOTICE 'Processing block range: <%,%>', __from, __to;

        IF __from != __to THEN
          CALL cab_app.do_massive_processing(_appContext, __from, __to, _step, __last_block);
        ELSE
          PERFORM cab_app.do_single_block_processing(_appContext, __to);
          __last_block := __to;
        END IF;
      END IF;
    END LOOP;

  RAISE NOTICE 'Exiting application main loop at processed block: %.', __last_block;

  CALL cab_app.finalize_app(_appContext, _consensus_storage , __last_block);

END$$;

CREATE OR REPLACE PROCEDURE cab_app.prepare_app_data(
  IN _appContext VARCHAR,
  IN _consensus_storage TEXT,
  INOUT _last_block INT
) LANGUAGE 'plpgsql' AS $$
BEGIN

  CREATE TABLE IF NOT EXISTS cab_app.LOG_TABLE(
    first_block int,
    last_block int,
    time interval
  );
  
  IF NOT hive.app_context_exists(_appContext) THEN
    RAISE NOTICE 'Creating the HAF application context...';
    PERFORM hive.app_create_context(_appContext);
    COMMIT;
    
    RAISE NOTICE 'all tables = %', json_agg(t)
      FROM(
        SELECT
          *
        FROM
          pg_catalog.pg_tables
        WHERE
          schemaname != 'pg_catalog'
          AND schemaname != 'information_schema') t;

    RAISE NOTICE 'Naprawde hive.contexts = %', json_agg(t)
      FROM(
        SELECT
          *
        FROM
          hive.contexts) t;

    PERFORM cab_app.define_schema();
    PERFORM hive.app_state_provider_import('KEYAUTH', _appContext);
    PERFORM hive.app_state_provider_import('ACCOUNTS', _appContext);
    PERFORM hive.app_state_provider_import('c_a_b_s_t', _appContext, _consensus_storage || '/' || _appContext);
    COMMIT;
  END IF;

  PERFORM cab_app.set_total_time_start(now());


  PERFORM cab_app.allow_processing();
  COMMIT;

  SELECT cab_app.last_processed_block() INTO _last_block;

  RAISE NOTICE 'Last block processed by application: %', _last_block;


  IF NOT hive.app_context_is_attached(_appContext) THEN
    PERFORM hive.app_context_attach(_appContext, _last_block);
  END IF;

END$$;

CREATE OR REPLACE FUNCTION cab_app.define_schema() RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  RAISE NOTICE 'Creating application schema tables...';
  CREATE TABLE IF NOT EXISTS cab_app.app_status(
    continue_processing BOOLEAN NOT NULL,
    last_processed_block INT NOT NULL,
    total_time_start TIMESTAMP WITH TIME ZONE,
    temp_time_start TIMESTAMP WITH TIME ZONE
  );

  INSERT INTO cab_app.app_status(continue_processing, last_processed_block) VALUES(TRUE, 0);

  RAISE NOTICE 'hive.cabc = %', json_agg(t) FROM(SELECT * FROM hive.cabc) t;

  -- -- A dummy table to make this application the forking application
  -- CREATE TABLE IF NOT EXISTS cab_app.dummy_table( ) INHERITS(hive.cabc);
END$$;

CREATE OR REPLACE PROCEDURE cab_app.adjust_block_range(
  INOUT _from INT,
  INOUT _to INT,
  IN _maxBlockLimit INT
) LANGUAGE plpgsql AS $$
BEGIN
  IF _maxBlockLimit != 0 AND _from > _maxBlockLimit THEN
    _from := _maxBlockLimit;
  END IF;

  IF _maxBlockLimit != 0 AND _to > _maxBlockLimit THEN
    _to := _maxBlockLimit;
  END IF;
END$$;

CREATE OR REPLACE PROCEDURE cab_app.do_massive_processing(
  IN _appContext VARCHAR,
  IN _from INT,
  IN _to INT,
  IN _step INT,
  INOUT _last_block INT
) LANGUAGE 'plpgsql' AS $$
BEGIN
  PERFORM cab_app.set_temp_time_start(now());
  RAISE NOTICE 'Entering massive processing of block range: <%, %>...', _from, _to;
  RAISE NOTICE 'Detaching HAF application context...';
  PERFORM hive.app_context_detach(_appContext);
  --- You can do here also other things to speedup your app, i.e. disable constrains, remove indexes etc.
  
  CALL cab_app.process_block_range_loop(_appContext, _from, _to, _step, _last_block);

  CALL cab_app.process_block_range_rest(_appContext, _from, _to, _last_block);


  RAISE NOTICE 'Attaching HAF application context at block: %.', _last_block;
  PERFORM hive.app_context_attach(_appContext, _last_block);
  --- You should enable here all things previously disabled at begin of this function...
  RAISE NOTICE 'Leaving massive processing of block range: <%, %>...', _from, _to;

  PERFORM cab_app.record_time(_from, _to, cab_app.get_temp_time_start());
  RAISE NOTICE 'Massive processing time = %', now() - cab_app.get_temp_time_start();

END$$;

CREATE OR REPLACE FUNCTION cab_app.do_single_block_processing(IN _appContext VARCHAR, IN _block INT) RETURNS VOID LANGUAGE 'plpgsql' AS $$
BEGIN
  PERFORM cab_app.set_temp_time_start(now());

  PERFORM cab_app.process_block_range_data_c(_appContext, _block, _block);
  COMMIT;
  -- For single block processing we want to commit all changes for each one.

  PERFORM cab_app.record_time(_block, _block, cab_app.get_temp_time_start());
  RAISE NOTICE 'One block processing time = %', now() - cab_app.get_temp_time_start();

END
$$;

CREATE OR REPLACE PROCEDURE cab_app.process_block_range_loop(
  IN _appContext VARCHAR,
  IN _from INT,
  IN _to INT,
  IN _step INT,
  INOUT _last_block INT
) LANGUAGE 'plpgsql' AS $$
BEGIN
  FOR b IN _from.._to BY
    _step LOOP
      _last_block := b + _step - 1;
      IF _last_block > _to THEN
        --- in case the _step is larger than range length
        _last_block := _to;
      END IF;
      RAISE NOTICE 'Processing block range: <%, %>', b, _last_block;
      PERFORM cab_app.process_block_range_data_c(_appContext, b, _last_block);
      COMMIT;
      RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;
      EXIT
      WHEN NOT cab_app.continue_processing();
    END LOOP;
END$$;

CREATE OR REPLACE PROCEDURE cab_app.process_block_range_rest(
  IN _appContext VARCHAR,
  IN _from INT,
  IN _to INT,
  INOUT _last_block INT
) LANGUAGE 'plpgsql' AS $$
BEGIN
  IF cab_app.continue_processing() AND _last_block < _to THEN
    RAISE NOTICE 'Processing block range(rest): <%, %>', b, _last_block;
    --- Supplement last part of range if anything left.
    PERFORM cab_app.process_block_range_data_c(_last_block, _to);
    _last_block := _to;
    COMMIT;
    RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;
  END IF;
END$$;

CREATE OR REPLACE FUNCTION cab_app.process_block_range_data_c(
  _app_context VARCHAR,
  _from INT,
  _to INT,
  _report_step INT = 1000
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    PERFORM hive.app_state_providers_update(_from, _to, _app_context);
END$$;

CREATE OR REPLACE PROCEDURE cab_app.finalize_app(
  IN _appContext VARCHAR,
  IN _consensus_storage TEXT,
  INOUT _last_block INT
) LANGUAGE 'plpgsql' AS $$
BEGIN
  PERFORM cab_app.store_last_processed_block(_last_block);
  COMMIT;
  
  IF hive.app_is_forking(_appContext) THEN
    RAISE NOTICE 'This is a forking Application';
  ELSE
    RAISE NOTICE 'This is a non-forking application';
  END IF;
  
  RAISE NOTICE 'Collected keys count=%',(
    SELECT
      json_agg(t)
    FROM(
      SELECT
        count(*)
      FROM
        hive.cabc_keyauth) t);
  
  PERFORM cab_app.display_stats('Massive processing', 'WHERE last_block - first_block > 0');
  PERFORM cab_app.display_stats('One block processing', 'WHERE last_block - first_block = 0');
  
  RAISE NOTICE 'Total time = %', now() - cab_app.get_total_time_start();

END$$;

CREATE OR REPLACE FUNCTION cab_app.display_stats(_prefix VARCHAR, _condition VARCHAR) RETURNS void LANGUAGE 'plpgsql' AS $$
DECLARE
  __sum_time INTERVAL;
  __count INT;
BEGIN
  EXECUTE format('SELECT SUM(time) FROM cab_app.log_table %s', _condition) INTO __sum_time;
  
  RAISE NOTICE '% sum time = %', _prefix, __sum_time;
  
  EXECUTE format('SELECT count(*) FROM cab_app.log_table %s', _condition) INTO __count;
  
  RAISE NOTICE '%s count = %', _prefix, __count;
  
  IF __count <> 0 THEN
    RAISE NOTICE '%s average time = %', _prefix, __sum_time / __count;
  END IF;
END$$;

--- Helper function telling application main-loop to continue execution.
CREATE OR REPLACE FUNCTION cab_app.continue_processing() RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
    RETURN continue_processing FROM cab_app.app_status LIMIT 1;
END$$;

CREATE OR REPLACE FUNCTION cab_app.allow_processing() RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE cab_app.app_status SET continue_processing = TRUE;
END$$;

--- Helper function to be called from separate transaction(must be committed) to safely stop execution of the application.
CREATE OR REPLACE FUNCTION cab_app.stop_processing() RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE cab_app.app_status SET continue_processing = FALSE;
END$$;

CREATE OR REPLACE FUNCTION cab_app.store_last_processed_block(_last_block INT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE cab_app.app_status SET last_processed_block = _last_block;
END$$;

CREATE OR REPLACE FUNCTION cab_app.last_processed_block() RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
    RETURN last_processed_block FROM cab_app.app_status LIMIT 1;
END$$;

CREATE OR REPLACE FUNCTION cab_app.get_total_time_start() RETURNS TIMESTAMP WITH TIME ZONE LANGUAGE plpgsql AS $$
BEGIN
    RETURN total_time_start FROM cab_app.app_status;
END$$;

CREATE OR REPLACE FUNCTION cab_app.set_total_time_start(IN _total_time_start TIMESTAMP WITH TIME ZONE) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE cab_app.app_status SET total_time_start = _total_time_start;
END$$;

CREATE OR REPLACE FUNCTION cab_app.get_temp_time_start() RETURNS TIMESTAMP WITH TIME ZONE LANGUAGE plpgsql AS $$
BEGIN
    RETURN temp_time_start FROM cab_app.app_status;
END$$;

CREATE OR REPLACE FUNCTION cab_app.set_temp_time_start(IN _temp_time_start TIMESTAMP WITH TIME ZONE) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE cab_app.app_status SET temp_time_start = _temp_time_start;
END$$;

CREATE OR REPLACE FUNCTION cab_app.record_time(
  IN _from INT,
  IN _to INT,
  IN _start_time TIMESTAMP WITH TIME ZONE
) RETURNS VOID LANGUAGE 'plpgsql' AS $$
BEGIN
    INSERT INTO cab_app.LOG_TABLE
    VALUES(_from, _to, now() - _start_time);
END$$;