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
    RETURN QUERY SELECT * FROM hive.irreversible_data;
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
    --PERFORM hive.force_irr_data_insert();
    UPDATE hive.irreversible_data SET is_dirty = flag;

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
    --PERFORM hive.force_irr_data_insert();
    UPDATE hive.irreversible_data SET consistent_block = num;

    --INSERT INTO hive.irreversible_data_renamed (id, consistent_block, is_dirty) VALUES (1, num, FALSE) 
    --ON CONFLICT (id) DO UPDATE SET consistent_block = num;

END;
$BODY$
;


DROP TYPE IF EXISTS hive.foorks_data_type;
CREATE TYPE hive.foorks_data_type AS (
    id BIGINT ,
    block_num INT , -- head block number, after reverting all blocks from fork (look for `notify_switch_fork` in database.cpp hive project file )
    time_of_fork TIMESTAMP WITHOUT TIME ZONE -- time of receiving notification from hived (see: hive.back_from_fork definition)
    );



CREATE OR REPLACE FUNCTION hive.get_hive_foorks()
    RETURNS SETOF hive.foorks_data_type
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
BEGIN
    RETURN QUERY SELECT * FROM hive.fork;
END;
$BODY$
;

