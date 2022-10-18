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

CREATE TYPE hive.block_type_ext AS (
    block_num INTEGER,
    block hive.block_type
);

CREATE OR REPLACE FUNCTION hive.get_block_from_views( _block_num_start INT, _block_count INT )
    RETURNS SETOF hive.block_type_ext
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    _empty_jsonb_array JSONB := array_to_json(ARRAY[] :: INT[]) :: JSONB;
    _block_num_end INTEGER;
BEGIN

    SELECT _block_num_start + _block_count INTO _block_num_end;

    RETURN QUERY
        WITH
        base_blocks_data AS (
            SELECT
                hb.num,
                hb.prev,
                hb.created_at,
                hb.transaction_merkle_root,
                hb.witness_signature,
                COALESCE(hb.extensions, _empty_jsonb_array) AS extensions,
                hb.producer_account_id,
                hb.hash,
                hb.signing_key,
                ha.name
            FROM hive.blocks_view hb
            JOIN hive.accounts_view ha ON hb.producer_account_id = ha.id
            WHERE hb.num >= _block_num_start AND hb.num < _block_num_end
            ORDER BY hb.num ASC
        ),
        trx_details AS (
            SELECT
                htv.block_num,
                htv.trx_in_block,
                htv.expiration,
                htv.ref_block_num,
                htv.ref_block_prefix,
                htv.trx_hash,
                htv.signature
            FROM hive.transactions_view htv
            WHERE htv.block_num >= _block_num_start AND htv.block_num < _block_num_end
            ORDER BY htv.block_num ASC, htv.trx_in_block ASC
        ),
        operations AS (
                SELECT ho.block_num, ho.trx_in_block, ARRAY_AGG(ho.body ORDER BY op_pos ASC) bodies
                FROM hive.operations_view ho
                WHERE
                    ho.op_type_id <= (SELECT ot.id FROM hive.operation_types ot WHERE ot.is_virtual = FALSE ORDER BY ot.id DESC LIMIT 1) 
                    AND ho.block_num >= _block_num_start AND ho.block_num < _block_num_end
                GROUP BY ho.block_num, ho.trx_in_block
                ORDER BY ho.block_num ASC, trx_in_block ASC
        ),
        full_transactions_with_signatures AS (
                SELECT
                    htv.block_num,
                    ARRAY_AGG(htv.trx_hash ORDER BY htv.trx_in_block ASC) AS trx_hashes,
                    ARRAY_AGG(
                        (
                            htv.ref_block_num,
                            htv.ref_block_prefix,
                            htv.expiration,
                            ops.bodies,
                            _empty_jsonb_array,
                            (
                                CASE
                                    WHEN multisigs.signatures = ARRAY[NULL]::BYTEA[] THEN ARRAY[ htv.signature ]::BYTEA[]
                                    ELSE htv.signature || multisigs.signatures
                                END
                            )
                        ) :: hive.transaction_type
                    ) AS transactions
                FROM
                (
                    SELECT txd.trx_hash, ARRAY_AGG(htmv.signature) AS signatures
                    FROM trx_details txd
                    LEFT JOIN hive.transactions_multisig_view htmv
                    ON txd.trx_hash = htmv.trx_hash
                    GROUP BY txd.trx_hash
                ) AS multisigs
                JOIN trx_details htv ON htv.trx_hash = multisigs.trx_hash
                JOIN operations ops ON ops.block_num = htv.block_num AND htv.trx_in_block = ops.trx_in_block
                GROUP BY htv.block_num
                ORDER BY htv.block_num ASC
        )
        SELECT
            bbd.num,
            (
                bbd.prev,
                bbd.created_at,
                bbd.name,
                bbd.transaction_merkle_root,
                bbd.extensions,
                bbd.witness_signature,
                ftws.transactions,
                bbd.hash,
                bbd.signing_key,
                ftws.trx_hashes
            ) :: hive.block_type
        FROM base_blocks_data bbd
        LEFT JOIN full_transactions_with_signatures ftws ON ftws.block_num = bbd.num
        ORDER BY bbd.num ASC
        ;
END;
$BODY$
;
