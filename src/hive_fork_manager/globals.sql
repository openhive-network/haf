CREATE OR REPLACE FUNCTION hive.force_irr_data_insert()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
BEGIN

    IF (select count(*) from hive.irreversible_data_renamed) = 0 THEN
        raise NOTICE 'MTTK INSERT INTO hive.irreversible_data_renamed Values(1, null, FALSE)';
        INSERT INTO hive.irreversible_data_renamed Values(1, null, FALSE);
    END IF;

END;
$BODY$
;



DROP TYPE IF EXISTS hive.irr_data_type;
CREATE TYPE hive.irr_data_type AS (
      id integer,
      consistent_block integer,
      is_dirty bool 
    );

CREATE OR REPLACE FUNCTION hive.get_irr_data()
    RETURNS SETOF hive.irr_data_type
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
BEGIN
    RETURN QUERY SELECT * FROM hive.irreversible_data_renamed;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.update_irr_data_dirty(flag boolean)
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
BEGIN
    PERFORM hive.force_irr_data_insert();
    UPDATE hive.irreversible_data_renamed SET is_dirty = flag;

    --INSERT INTO hive.irreversible_data_renamed (id, is_dirty) VALUES (1, flag) 
    --ON CONFLICT (id) DO UPDATE SET is_dirty = flag;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_irr_data_consistent_block(num integer)
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
BEGIN
    PERFORM hive.force_irr_data_insert();
    UPDATE hive.irreversible_data_renamed SET consistent_block = num;

    --INSERT INTO hive.irreversible_data_renamed (id, consistent_block, is_dirty) VALUES (1, num, FALSE) 
    --ON CONFLICT (id) DO UPDATE SET consistent_block = num;

END;
$BODY$
;

