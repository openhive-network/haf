CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TABLE public.constraints_before AS
    SELECT conrelid::regclass::text AS table_name, conname, contype, pg_get_constraintdef( oid ) AS definition
    FROM pg_constraint
    WHERE connamespace = 'hafd'::regnamespace AND contype IN ( 'p', 'u' );

    CREATE TABLE public.indexes_before AS
    SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'hafd';

    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible( 'keep-monotonic' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.enable_indexes_of_irreversible();
    PERFORM hive.enable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE status != 'created' ), 'Not every index was restored';
    ASSERT hive.is_instance_ready(), 'is_instance_ready() is false after the restore';
    ASSERT hive.are_core_indexes_created( 'hafd.account_operations' ), 'hafd.account_operations is reported incomplete';

    -- the deferred PK/UNIQUE constraints come back as constraints with their original definition
    ASSERT NOT EXISTS(
        SELECT table_name, conname, contype, definition FROM public.constraints_before
        EXCEPT
        SELECT conrelid::regclass::text, conname, contype, pg_get_constraintdef( oid )
        FROM pg_constraint WHERE connamespace = 'hafd'::regnamespace AND contype IN ( 'p', 'u' )
    ), 'A PK/UNIQUE constraint was not restored as it was';

    ASSERT NOT EXISTS(
        SELECT * FROM public.indexes_before
        EXCEPT
        SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'hafd'
    ), 'An index was not restored as it was';
END;
$BODY$
;
