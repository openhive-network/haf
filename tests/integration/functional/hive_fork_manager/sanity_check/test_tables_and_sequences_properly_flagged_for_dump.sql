--This test checks if all tables and sequences in the haf extension are flagged with pg_extension_config_dump
--in order to be emitted by pg_dump (normally extension tables and sequences are not dumped)



CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    all_sequences TEXT[];
    all_tables TEXT[];
    oids INTEGER[];
    flagged_tables TEXT[];
    flagged_sequences TEXT[];
BEGIN

    SELECT ARRAY_AGG(sequence_name) INTO all_sequences
    FROM information_schema.sequences 
    WHERE sequence_name <> 'deps_saved_ddl_deps_id_seq'
    AND ( sequence_schema = 'hive' OR sequence_schema = 'hafd' );

    SELECT ARRAY_AGG(table_name ORDER BY table_name) INTO all_tables
    FROM  information_schema.tables
    WHERE ( table_schema = 'hive' OR table_schema = 'hafd'  )and table_type <> 'VIEW' and table_name <> 'deps_saved_ddl'
    ;

    SELECT extconfig into oids FROM pg_extension WHERE extname = 'hive_fork_manager';

    SELECT ARRAY_AGG(t.relname ORDER BY relname) INTO flagged_tables
    FROM (
            SELECT oid, relname FROM (SELECT unnest(extconfig) as extconfig  FROM
                (SELECT extconfig FROM pg_extension WHERE extname = 'hive_fork_manager' ) u
                ) as t JOIN pg_class ON oid = extconfig
                WHERE relkind <> 'S'
        ) t;

    SELECT ARRAY_AGG(t.relname) INTO flagged_sequences
    FROM (
            SELECT oid, relname FROM (SELECT unnest(extconfig) as extconfig  FROM
                (SELECT extconfig FROM pg_extension WHERE extname = 'hive_fork_manager' ) u
            ) as t JOIN pg_class ON oid = extconfig WHERE relkind = 'S'
        ) t;

    assert test.unordered_arrays_equal(all_tables, flagged_tables), format_assert_message('tables', all_tables, flagged_tables);
    assert test.unordered_arrays_equal(all_sequences, flagged_sequences), format_assert_message('sequences', all_sequences, flagged_sequences);

END
$BODY$
;


DROP FUNCTION IF EXISTS format_assert_message;
CREATE FUNCTION format_assert_message(IN intext TEXT, IN alla TEXT[], IN flagged TEXT[])
    RETURNS TEXT
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    return format('Existing ' || intext || ' in hive/hafd schema:' ||E'\n'|| '%s, ' ||E'\n'|| 'but flagged with pg_extension_config_dump are:'||E'\n'||'%s', alla, flagged);
END
$BODY$
;

