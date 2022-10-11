DROP TABLE IF EXISTS hive.indexes_constraints;
CREATE TABLE IF NOT EXISTS hive.indexes_constraints (
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    command text NOT NULL,
    is_constraint boolean NOT NULL,
    is_index boolean NOT NULL,
    is_foreign_key boolean NOT NULL,
    CONSTRAINT pk_hive_indexes_constraints UNIQUE( table_name, index_constraint_name )
);

CREATE OR REPLACE FUNCTION hive.copy_blocks_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    SELECT
          DISTINCT ON ( hbr.num ) hbr.num
        , hbr.hash
        , hbr.prev
        , hbr.created_at
        , hbr.producer_account_id
        , hbr.transaction_merkle_root
        , hbr.extensions
        , hbr.witness_signature
        , hbr.signing_key
    FROM
        hive.blocks_reversible hbr
    WHERE
        hbr.num <= _new_irreversible_block
    AND hbr.num > _head_block_of_irreversible_blocks
    ORDER BY hbr.num ASC, hbr.fork_id DESC;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_transactions_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.transactions
    SELECT
          htr.block_num
        , htr.trx_in_block
        , htr.trx_hash
        , htr.ref_block_num
        , htr.ref_block_prefix
        , htr.expiration
        , htr.signature
    FROM
        hive.transactions_reversible htr
    JOIN ( SELECT
              DISTINCT ON ( hbr.num ) hbr.num
            , hbr.fork_id
            FROM hive.blocks_reversible hbr
            WHERE
                    hbr.num <= _new_irreversible_block
                AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
    ) as num_and_forks ON htr.block_num = num_and_forks.num AND htr.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_operations_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operations
    SELECT
           hor.id
         , hor.block_num
         , hor.trx_in_block
         , hor.op_pos
         , hor.op_type_id
         , hor.timestamp
         , hor.body
    FROM
        hive.operations_reversible hor
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
            WHERE
                  hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON hor.block_num = num_and_forks.num AND hor.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.copy_applied_hardforks_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.applied_hardforks
    SELECT
           hjr.hardfork_num
         , hjr.block_num
         , hjr.hardfork_vop_id
    FROM
        hive.applied_hardforks_reversible hjr
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
            WHERE
                  hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON hjr.block_num = num_and_forks.num AND hjr.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_signatures_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.transactions_multisig
    SELECT
          tsr.trx_hash
        , tsr.signature
    FROM
        hive.transactions_multisig_reversible tsr
        JOIN hive.transactions_reversible htr ON htr.trx_hash = tsr.trx_hash AND htr.fork_id = tsr.fork_id
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
            WHERE
                    hbr.num <= _new_irreversible_block
                AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON htr.block_num = num_and_forks.num AND htr.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_accounts_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.accounts
    SELECT
           har.id
         , har.name
         , har.block_num
    FROM
        hive.accounts_reversible har
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
            WHERE
                  hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON har.block_num = num_and_forks.num AND har.fork_id = num_and_forks.fork_id
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.copy_account_operations_to_irreversible(
      _head_block_of_irreversible_blocks INT
    , _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.account_operations
    SELECT
           haor.block_num
         , haor.account_id
         , haor.account_op_seq_no
         , haor.operation_id
         , haor.op_type_id
    FROM
        hive.account_operations_reversible haor
        JOIN (
            SELECT
                  DISTINCT ON ( hbr.num ) hbr.num
                , hbr.fork_id
            FROM hive.blocks_reversible hbr
            WHERE
                hbr.num <= _new_irreversible_block
              AND hbr.num > _head_block_of_irreversible_blocks
            ORDER BY hbr.num ASC, hbr.fork_id DESC
        ) as num_and_forks ON haor.fork_id = num_and_forks.fork_id AND haor.block_num = num_and_forks.num
    ;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    DELETE FROM hive.account_operations_reversible har
    USING hive.operations_reversible hor
    WHERE
            har.operation_id = hor.id
        AND har.fork_id = hor.fork_id
        AND hor.block_num <= _new_irreversible_block
    ;

    DELETE FROM hive.applied_hardforks_reversible hjr
    WHERE hjr.block_num <= _new_irreversible_block;

    DELETE FROM hive.operations_reversible hor
    WHERE hor.block_num <= _new_irreversible_block;


    DELETE FROM hive.transactions_multisig_reversible htmr
    USING hive.transactions_reversible htr
    WHERE
            htr.fork_id = htmr.fork_id
        AND htr.trx_hash = htmr.trx_hash
        AND htr.block_num <= _new_irreversible_block
    ;

    DELETE FROM hive.transactions_reversible htr
    WHERE htr.block_num <= _new_irreversible_block;

    DELETE FROM hive.accounts_reversible har
    WHERE har.block_num <= _new_irreversible_block;

    DELETE FROM hive.blocks_reversible hbr
    WHERE hbr.num <= _new_irreversible_block;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.remove_unecessary_events( _new_irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __upper_bound_events_id BIGINT := NULL;
    __max_block_num INTEGER := NULL;
BEGIN
    SELECT consistent_block INTO __max_block_num FROM hive.irreversible_data;

    -- find the upper bound of events possible to remove
    SELECT MIN(heq.id) INTO __upper_bound_events_id
    FROM hive.events_queue heq
    WHERE heq.event != 'BACK_FROM_FORK' AND heq.block_num = ( _new_irreversible_block + 1 ); --next block after irreversible

    DELETE FROM hive.events_queue heq
    USING ( SELECT MIN( hc.events_id) as id FROM hive.contexts hc ) as min_event
    WHERE ( heq.id < __upper_bound_events_id OR __upper_bound_events_id IS NULL )  AND ( heq.id < min_event.id OR min_event.id IS NULL ) AND heq.id != 0;

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.save_and_drop_indexes_constraints( in _schema TEXT, in _table TEXT )
    RETURNS VOID
    AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN
    PERFORM hive.save_and_drop_constraints( _schema, _table );

    --LEFT JOIN is needed in situation when PRIMARY KEY exists in a `_table`.
    --A method `hive.save_and_drop_constraints` finds it, but following code finds an index related to given PK as well.
    --Since dropping/restoring PK automatically drops/restores an index, then it's better to avoid storing a record with index related to PK.
    INSERT INTO hive.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key )
    SELECT
        T.indexname
      , _schema || '.' || _table
      , T.indexdef
      , FALSE as is_constraint
      , TRUE as is_index
      , FALSE as is_foreign_key
    FROM
    (
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE schemaname = _schema AND tablename = _table
    ) T LEFT JOIN hive.indexes_constraints ic ON( T.indexname = ic.index_constraint_name )
    WHERE ic.table_name is NULL
    ON CONFLICT DO NOTHING;

    --dropping indexes
    OPEN __cursor FOR (
        SELECT ('DROP INDEX IF EXISTS '::TEXT || _schema || '.' || index_constraint_name || ';')
        FROM hive.indexes_constraints WHERE table_name = _schema || '.' || _table AND is_index = TRUE
    );

    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;

    --dropping primary keys/unique contraints
    OPEN __cursor FOR (
        SELECT ('ALTER TABLE '::TEXT || _schema || '.' || _table || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';')
        FROM hive.indexes_constraints WHERE table_name = _schema || '.' || _table AND is_constraint = TRUE
    );

    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.save_and_drop_indexes_foreign_keys( in _table_schema TEXT, in _table_name TEXT )
RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN
    INSERT INTO hive.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key )
    SELECT
          DISTINCT ON ( pgc.conname ) pgc.conname as constraint_name
        , _table_schema || '.' || _table_name as table_name
        , 'ALTER TABLE ' || tc.table_schema || '.' || tc.table_name || ' ADD CONSTRAINT ' || pgc.conname || ' ' || pg_get_constraintdef(pgc.oid) as command
        , FALSE as is_constraint
        , FALSE AS is_index
        , TRUE as is_foreign_key
    FROM pg_constraint pgc
    JOIN pg_namespace nsp on nsp.oid = pgc.connamespace
    JOIN information_schema.table_constraints tc ON pgc.conname = tc.constraint_name AND nsp.nspname = tc.constraint_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = _table_schema AND tc.table_name = _table_name;

    OPEN __cursor FOR (
        SELECT ('ALTER TABLE '::TEXT || _table_schema || '.' || _table_name || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';')
        FROM hive.indexes_constraints WHERE table_name = ( _table_schema || '.' || _table_name ) AND is_foreign_key = TRUE
    );

    LOOP
        FETCH __cursor INTO __command;
            EXIT WHEN NOT FOUND;
            EXECUTE __command;
    END LOOP;

    CLOSE __cursor;
END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.save_and_drop_constraints( in _table_schema TEXT, in _table_name TEXT )
RETURNS VOID
AS
$function$
DECLARE
__command TEXT;
__cursor REFCURSOR;
BEGIN
    INSERT INTO hive.indexes_constraints( index_constraint_name, table_name, command, is_constraint, is_index, is_foreign_key )
    SELECT
        DISTINCT ON ( pgc.conname ) pgc.conname as constraint_name
        , _table_schema || '.' || _table_name as table_name
        , 'ALTER TABLE ' || tc.table_schema || '.' || tc.table_name || ' ADD CONSTRAINT ' || pgc.conname || ' ' || pg_get_constraintdef(pgc.oid) as command
        , tc.constraint_type = 'PRIMARY KEY' OR tc.constraint_type = 'UNIQUE' as is_constraint
        , FALSE AS is_index
        , FALSE as is_foreign_key
    FROM pg_constraint pgc
        JOIN pg_namespace nsp on nsp.oid = pgc.connamespace
        JOIN information_schema.table_constraints tc ON pgc.conname = tc.constraint_name AND nsp.nspname = tc.constraint_schema
    WHERE tc.constraint_type != 'FOREIGN KEY' AND tc.table_schema = _table_schema AND tc.table_name = _table_name;

    OPEN __cursor FOR (
            SELECT ('ALTER TABLE '::TEXT || _table_schema || '.' || _table_name || ' DROP CONSTRAINT IF EXISTS ' || index_constraint_name || ';')
            FROM hive.indexes_constraints WHERE table_name = ( _table_schema || '.' || _table_name ) AND is_foreign_key = TRUE
        );

        LOOP
    FETCH __cursor INTO __command;
                EXIT WHEN NOT FOUND;
                EXECUTE __command;
    END LOOP;

        CLOSE __cursor;
    END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.restore_indexes( in _table_name TEXT )
    RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN

    --restoring indexes, primary keys, unique contraints
    OPEN __cursor FOR ( SELECT command FROM hive.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = FALSE );
    LOOP
        FETCH __cursor INTO __command;
            EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;

    DELETE FROM hive.indexes_constraints
    WHERE table_name = _table_name AND is_foreign_key = FALSE;

END;
$function$
LANGUAGE plpgsql VOLATILE
;


CREATE OR REPLACE FUNCTION hive.restore_foreign_keys( in _table_name TEXT )
    RETURNS VOID
AS
$function$
DECLARE
    __command TEXT;
    __cursor REFCURSOR;
BEGIN

    --restoring indexes, primary keys, unique contraints
    OPEN __cursor FOR ( SELECT command FROM hive.indexes_constraints WHERE table_name = _table_name AND is_foreign_key = TRUE );
    LOOP
    FETCH __cursor INTO __command;
        EXIT WHEN NOT FOUND;
        EXECUTE __command;
    END LOOP;
    CLOSE __cursor;

    DELETE FROM hive.indexes_constraints
    WHERE table_name = _table_name AND is_foreign_key = TRUE;

END;
$function$
LANGUAGE plpgsql VOLATILE
;

CREATE OR REPLACE FUNCTION hive.remove_inconsistent_irreversible_data()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __consistent_block INTEGER := NULL;
    __is_dirty BOOL := TRUE;
BEGIN
    SELECT consistent_block, is_dirty INTO __consistent_block, __is_dirty FROM hive.irreversible_data;

    IF ( __is_dirty = FALSE ) THEN
        RETURN;
    END IF;

    DELETE FROM hive.account_operations hao
    WHERE hao.block_num > __consistent_block;

    DELETE FROM hive.applied_hardforks WHERE block_num > __consistent_block;

    DELETE FROM hive.operations WHERE block_num > __consistent_block;

    DELETE FROM hive.transactions_multisig htm
    USING hive.transactions ht
    WHERE ht.block_num > __consistent_block AND ht.trx_hash = htm.trx_hash;

    DELETE FROM hive.transactions WHERE block_num > __consistent_block;

    DELETE FROM hive.accounts WHERE block_num > __consistent_block;

    DELETE FROM hive.blocks WHERE num > __consistent_block;

    UPDATE hive.irreversible_data SET is_dirty = FALSE;
END;
$BODY$
;

DROP TYPE IF EXISTS hive.transaction_type;
CREATE TYPE hive.transaction_type AS (
      ref_block_num integer
    , ref_block_prefix bigint
    , expiration TIMESTAMP WITHOUT TIME ZONE
    , operations text[]
    , extensions jsonb
    , signatures bytea[]
    );

DROP TYPE IF EXISTS hive.block_type;
CREATE TYPE hive.block_type AS (
      previous bytea
    , timestamp TIMESTAMP WITHOUT TIME ZONE
    , witness VARCHAR(16)
    , transaction_merkle_root bytea
    , extensions jsonb
    , witness_signature bytea
    , transactions hive.transaction_type[]
    , block_id bytea
    , signing_key text
    , transaction_ids bytea[]
    );

CREATE OR REPLACE FUNCTION hive.get_block_from_views( _block_num INT )
    RETURNS hive.block_type
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __witness_account_id INTEGER;
    __result hive.block_type := NULL;
BEGIN
    SELECT
           hb.prev
         , hb.created_at
         , hb.transaction_merkle_root
         , hb.witness_signature
         , hb.extensions
         , hb.producer_account_id
         , hb.hash
         , hb.signing_key
    FROM hive.blocks_view hb
    WHERE hb.num = _block_num
    INTO
         __result.previous
       , __result.timestamp
       , __result.transaction_merkle_root
       , __result.witness_signature
       , __result.extensions
       , __witness_account_id
       , __result.block_id
       , __result.signing_key;

    SELECT ha.name
    FROM hive.accounts_view ha
    WHERE ha.id = __witness_account_id
    INTO __result.witness;


    WITH ht AS (
            SELECT *
            FROM hive.transactions_view
            WHERE block_num = _block_num
            ORDER BY trx_in_block
    ), operations AS (
            SELECT ho.block_num, ho.trx_in_block, ARRAY_AGG(ho.body) bodies
            FROM hive.operations_view ho
            WHERE
                ho.op_type_id < (SELECT ot.id FROM hive.operation_types ot WHERE ot.is_virtual = TRUE ORDER BY ot.id LIMIT 1)
                AND ho.block_num = _block_num
            GROUP BY ho.block_num, ho.trx_in_block
    ), multisig AS (
            SELECT trx_hash, ARRAY_AGG(signature) signatures
            FROM hive.transactions_multisig_view
            WHERE trx_hash = ANY(
                SELECT trx_hash FROM ht
            )
            GROUP BY trx_hash
    ), transactions AS (
            SELECT
                ht.ref_block_num ref_block_num, ht.ref_block_prefix ref_block_prefix
              , ht.expiration expiration, operations.bodies operations
              , NULL extensions, ht.signature || multisig.signatures signatures
              , ht.trx_hash trx_hash
            FROM ht
            LEFT JOIN operations ON ht.block_num = operations.block_num AND ht.trx_in_block = operations.trx_in_block
            LEFT JOIN multisig ON ht.trx_hash = multisig.trx_hash
            ORDER BY ht.trx_in_block
    )
    SELECT
        ARRAY_AGG( ROW(ref_block_num, ref_block_prefix, expiration, operations, extensions, signatures)::hive.transaction_type )
      , ARRAY_AGG(trx_hash)
    FROM transactions
    INTO __result.transactions, __result.transaction_ids;


    RETURN __result;
END;
$BODY$
;
