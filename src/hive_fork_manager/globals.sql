CREATE OR REPLACE FUNCTION hive.force_irr_data_insert()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
BEGIN

    IF (select count(*) from hive.irreversible_data) = 0 THEN
        raise NOTICE 'MTTK INSERT INTO hive.irreversible_data Values(1, null, FALSE)';
        INSERT INTO hive.irreversible_data Values(1, null, FALSE);
    END IF;

END;
$BODY$
;


