-- =============================================================
--  Application: Transaction Histogram (Non-Forking, SQL Version)
--  Uses hive.app_next_iteration() + application-level transactions
--  Commits only if ≥10 transactions were added, else rollbacks
-- =============================================================

-- 1. Prepare schema and result table
CREATE SCHEMA IF NOT EXISTS applications;

-- 2. Create non-forking context
SELECT hive.app_create_context(
    'trx_histogram_ctx',
    _schema => 'applications',
    _is_forking => FALSE,
    _stages => ARRAY[ hive.stage('massive',10 ,100 ), hafd.live_stage() ]
);



CREATE TABLE IF NOT EXISTS applications.trx_histogram (
                                                          day DATE PRIMARY KEY,
                                                          trx INT
);

-- 3. Register table for application-level transactions
SELECT hive.app_transaction_table_register('applications', 'trx_histogram', 'trx_histogram_ctx');

-- 4. Core processing logic
CREATE OR REPLACE FUNCTION applications.update_histogram(_first_block INT, _last_block INT)
    RETURNS INT
    LANGUAGE plpgsql
    VOLATILE
AS $$
DECLARE
    __added_tx INT := 0;
BEGIN
    -- Compute aggregated transaction counts per day
    WITH stats AS (
        SELECT DATE(hb.created_at) AS day, COUNT(*) AS trx
        FROM applications.blocks_view hb
                 JOIN applications.transactions_view ht ON ht.block_num = hb.num
        WHERE hb.num BETWEEN _first_block AND _last_block
        GROUP BY DATE(hb.created_at)
    )
    INSERT INTO applications.trx_histogram AS th(day, trx)
    SELECT s.day, s.trx
    FROM stats s
    ON CONFLICT (day)
    DO UPDATE SET trx = th.trx + EXCLUDED.trx;

    -- Sum total transactions added in this range
    SELECT COALESCE(COUNT(*), 0)
    INTO __added_tx
    FROM applications.blocks_view hb
             JOIN applications.transactions_view ht ON ht.block_num = hb.num
    WHERE hb.num BETWEEN _first_block AND _last_block;

    RETURN __added_tx;
END;
$$;

-- 5. Main loop
CREATE OR REPLACE PROCEDURE applications.run_histogram_app( _limit INT DEFAULT NULL )
    LANGUAGE plpgsql
AS $$
DECLARE
    __block_range hive.blocks_range;
    __first_block INT;
    __last_block  INT;
    __added_tx    INT := 0;
    __total_added BIGINT := 0;
    __number_of_collected_days INT := 0;
    __number_of_collected_tx INT := 0;
BEGIN
    LOOP
        -- Wait until next irreversible block range is ready
        CALL hive.app_next_iteration('trx_histogram_ctx', __block_range, _limit => _limit);

        -- No new range returned → continue waiting
        IF __block_range IS NULL THEN
            CONTINUE;
        END IF;

        __first_block := __block_range.first_block;
        __last_block  := __block_range.last_block;

        -- Start application-level transaction
        PERFORM hive.app_transaction_begin('trx_histogram_ctx');

        -- Process current block range
        __added_tx := applications.update_histogram(__first_block, __last_block);
        __total_added := __total_added + __added_tx;

        -- Decision: commit or rollback based on added tx count
        IF __added_tx < 10 THEN
            RAISE NOTICE 'Rolling back: only % transactions added in blocks %–%', __added_tx, __first_block, __last_block;
            PERFORM hive.app_transaction_rollback('trx_histogram_ctx');
        ELSE
            RAISE NOTICE 'Committing % transactions from blocks %–%', __added_tx, __first_block, __last_block;
            PERFORM hive.app_transaction_commit('trx_histogram_ctx');
        END IF;

        IF _limit IS NOT NULL THEN
            IF hive.app_get_current_block_num('trx_histogram_ctx') >= _limit THEN
                SELECT COUNT(*), SUM(trx) INTO __number_of_collected_days, __number_of_collected_tx
                FROM applications.trx_histogram;
                RAISE INFO 'Reached limit % of blocks. Collected % days with % transactions',
                    _limit, __number_of_collected_days, __number_of_collected_tx;
                RETURN;
            END IF;
        END IF;
    END LOOP;
END;
$$;

-- call to start the application
-- CALL applications.run_histogram_app();