

DROP SCHEMA IF EXISTS keyauth_app CASCADE;

CREATE SCHEMA IF NOT EXISTS keyauth_app;

CREATE OR REPLACE FUNCTION keyauth_app.define_schema()
RETURNS VOID
LANGUAGE 'plpgsql'
AS $$
BEGIN

RAISE NOTICE 'Attempting to create an application schema tables...';

CREATE TABLE IF NOT EXISTS keyauth_app.app_status
(
  continue_processing BOOLEAN NOT NULL,
  last_processed_block INT NOT NULL
);

INSERT INTO keyauth_app.app_status
(continue_processing, last_processed_block)
VALUES
(True, 0)
;

CREATE TABLE IF NOT EXISTS keyauth_app.dummy_table_to_make_it_forking_application
(
) 
INHERITS (hive.keyauth_app)
;
END
$$
;

--- Helper function telling application main-loop to continue execution.
CREATE OR REPLACE FUNCTION keyauth_app.continueProcessing()
RETURNS BOOLEAN
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN continue_processing FROM keyauth_app.app_status LIMIT 1;
END
$$
;

CREATE OR REPLACE FUNCTION keyauth_app.allowProcessing()
RETURNS VOID
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  UPDATE keyauth_app.app_status SET continue_processing = True;
END
$$
;

--- Helper function to be called from separate transaction (must be committed) to safely stop execution of the application.
CREATE OR REPLACE FUNCTION keyauth_app.stopProcessing()
RETURNS VOID
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  UPDATE keyauth_app.app_status SET continue_processing = False;
END
$$
;

CREATE OR REPLACE FUNCTION keyauth_app.storeLastProcessedBlock(IN _lastBlock INT)
RETURNS VOID
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  UPDATE keyauth_app.app_status SET last_processed_block = _lastBlock;
END
$$
;

CREATE OR REPLACE FUNCTION keyauth_app.lastProcessedBlock()
RETURNS INT
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RETURN last_processed_block FROM keyauth_app.app_status LIMIT 1;
END
$$
;

CREATE OR REPLACE FUNCTION keyauth_app.process_block_range_data_c(In _appContext VARCHAR, in _from INT, in _to INT, IN _report_step INT = 1000)
RETURNS VOID
LANGUAGE 'plpgsql'
AS
$$
BEGIN
    PERFORM hive.app_state_providers_update(_from, _to, _appContext);
END
$$
;

CREATE OR REPLACE PROCEDURE keyauth_app.do_massive_processing(IN _appContext VARCHAR, in _from INT, in _to INT, IN _step INT, INOUT _last_block INT)
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  RAISE NOTICE 'Entering massive processing of block range: <%, %>...', _from, _to;
  RAISE NOTICE 'Detaching HAF application context...';
  PERFORM hive.app_context_detach(_appContext);

  --- You can do here also other things to speedup your app, i.e. disable constrains, remove indexes etc.

  FOR b IN _from .. _to BY _step LOOP
    _last_block := b + _step - 1;

    IF _last_block > _to THEN --- in case the _step is larger than range length
      _last_block := _to;
    END IF;

    RAISE NOTICE 'Attempting to process a block range: <%, %>', b, _last_block;

    PERFORM keyauth_app.process_block_range_data_c(_appContext, b, _last_block);

    COMMIT;

    RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;


    EXIT WHEN NOT keyauth_app.continueProcessing();

  END LOOP;

  IF keyauth_app.continueProcessing() AND _last_block < _to THEN
    RAISE NOTICE 'Attempting to process a block range (rest): <%, %>', b, _last_block;
    --- Supplement last part of range if anything left.
    PERFORM keyauth_app.process_block_range_data_c(_last_block, _to);
    _last_block := _to;

    COMMIT;
    RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;
  END IF;

  RAISE NOTICE 'Attaching HAF application context at block: %.', _last_block;
  PERFORM hive.app_context_attach(_appContext, _last_block);

 --- You should enable here all things previously disabled at begin of this function...

 RAISE NOTICE 'Leaving massive processing of block range: <%, %>...', _from, _to;
END
$$
;

CREATE OR REPLACE PROCEDURE keyauth_app.processBlock(IN _appContext VARCHAR, in _block INT)
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  PERFORM keyauth_app.process_block_range_data_c(_appContext, _block, _block);
  COMMIT; -- For single block processing we want to commit all changes for each one.
END
$$
;



/** Application entry point, which:
  - defines its data schema,
  - creates HAF application context,
  - starts application main-loop (which iterates infinitely). To stop it call `keyauth_app.stopProcessing();` from another session and commit its trasaction.
*/
CREATE OR REPLACE PROCEDURE keyauth_app.main(IN _appContext VARCHAR, IN _maxBlockLimit INT = 0, IN _step INT = 0)
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __last_block INT;
  __next_block_range hive.blocks_range;

    total_time_start TIMESTAMP;
    temp_time_start TIMESTAMP;
    temp_interval INTERVAL;

BEGIN

  CREATE TABLE if not exists  keyauth_app.LOG_TABLE (first_block INT, last_block INT, time INTERVAL);
  total_time_start := clock_timestamp();

  IF NOT hive.app_context_exists(_appContext) THEN
    RAISE NOTICE 'Attempting to create a HAF application context...';
    PERFORM hive.app_create_context(_appContext);
    PERFORM keyauth_app.define_schema();
    PERFORM hive.app_state_provider_import('KEYAUTH', _appContext);
    PERFORM hive.app_state_provider_import('ACCOUNTS', _appContext);
    PERFORM hive.app_state_provider_import('CURRENT_ACCOUNT_BALANCE', _appContext);

    COMMIT;
  END IF;

  PERFORM keyauth_app.allowProcessing();
  COMMIT;

  SELECT keyauth_app.lastProcessedBlock() INTO __last_block;

  RAISE NOTICE 'Last block processed by application: %', __last_block;

  IF NOT hive.app_context_is_attached(_appContext) THEN
    PERFORM hive.app_context_attach(_appContext, __last_block);
  END IF;

  RAISE NOTICE 'Entering application main loop...';

  WHILE keyauth_app.continueProcessing() AND (_maxBlockLimit = 0 OR __last_block < _maxBlockLimit) LOOP
    __next_block_range := hive.app_next_block(_appContext);

    IF __next_block_range IS NULL THEN
      RAISE WARNING 'Waiting for next block...';
    ELSE
      IF _maxBlockLimit != 0 and __next_block_range.first_block > _maxBlockLimit THEN
        __next_block_range.first_block  := _maxBlockLimit;
      END IF;

      IF _maxBlockLimit != 0 and __next_block_range.last_block > _maxBlockLimit THEN
        __next_block_range.last_block  := _maxBlockLimit;
      END IF;

      RAISE NOTICE 'Attempting to process block range: <%,%>', __next_block_range.first_block, __next_block_range.last_block;

      IF __next_block_range.first_block != __next_block_range.last_block THEN
        temp_time_start = clock_timestamp();
        CALL keyauth_app.do_massive_processing(_appContext, __next_block_range.first_block, __next_block_range.last_block, _step, __last_block);
        temp_interval = clock_timestamp() - temp_time_start;
        INSERT INTO keyauth_app.LOG_TABLE VALUES(__next_block_range.first_block, __next_block_range.last_block, temp_interval);
        RAISE NOTICE 'Massive processing time = %', temp_interval;
      ELSE
        
        temp_time_start = clock_timestamp();
        CALL keyauth_app.processBlock(_appContext, __next_block_range.last_block);
        temp_interval = clock_timestamp() - temp_time_start;
        INSERT INTO keyauth_app.LOG_TABLE VALUES(__next_block_range.first_block, __next_block_range.last_block, temp_interval);
        RAISE NOTICE 'One block processing time = %', temp_interval;

        __last_block := __next_block_range.last_block;
      END IF;

    END IF;
  END LOOP;

  RAISE NOTICE 'Exiting application main loop at processed block: %.', __last_block;
  PERFORM keyauth_app.storeLastProcessedBlock(__last_block);
  
  COMMIT;

  if hive.app_is_forking(_appContext) then
      raise notice 'This is a forking Application';
  ELSE
      raise notice 'This is a non-forking application';
  END if;

  raise notice 'Collected keys count=%',
  (
      SELECT json_agg(t)
      FROM (
              SELECT count(*)
              FROM hive.keyauth_app_keyauth
          ) t
  );

  PERFORM keyauth_app.display_stats('Massive processing', 'WHERE last_block - first_block > 0');
  PERFORM keyauth_app.display_stats('One block processing', 'WHERE last_block - first_block = 0');
  RAISE NOTICE 'Total time = %', clock_timestamp() - total_time_start;
END
$$
;

CREATE OR REPLACE FUNCTION keyauth_app.display_stats(prefix VARCHAR, condition VARCHAR)
RETURNS void
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  sum_time INTERVAL;
  count INTEGER;
BEGIN
  EXECUTE format ('SELECT SUM(time) FROM keyauth_app.log_table %s', condition) INTO sum_time;
  RAISE NOTICE '% sum time = %', prefix, sum_time;

  EXECUTE format ('SELECT COUNT(*) FROM keyauth_app.log_table %s', condition) INTO count;
  RAISE NOTICE '%s count = %', prefix, count;
  IF count <> 0 THEN
      RAISE NOTICE '%s average time = %', prefix, sum_time / count;
  END IF;
END
$$
;

