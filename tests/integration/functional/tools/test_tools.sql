INSERT INTO hive.irreversible_data VALUES(1,NULL, FALSE) ON CONFLICT DO NOTHING;
INSERT INTO hive.events_queue VALUES( 0, 'NEW_IRREVERSIBLE', 0 ) ON CONFLICT DO NOTHING;
INSERT INTO hive.fork(block_num, time_of_fork) VALUES( 1, '2016-03-24 16:05:00'::timestamp ) ON CONFLICT DO NOTHING;
SELECT hive.create_database_hash('hive');


CREATE OR REPLACE FUNCTION hive.unordered_arrays_equal(arr1 TEXT[], arr2 TEXT[])
RETURNS bool
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
    return (arr1 <@ arr2 and arr1 @> arr2);
END
$$
;



CREATE SCHEMA toolbox;

CREATE FUNCTION toolbox.get_consensus_storage_path()
    RETURNS TEXT
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  __consensus_state_provider_storage_path TEXT;
BEGIN
     __consensus_state_provider_storage_path = '/home/hived/datadir/consensus_unit_test_storage_dir'; 
    RETURN __consensus_state_provider_storage_path;
END$BODY$;

