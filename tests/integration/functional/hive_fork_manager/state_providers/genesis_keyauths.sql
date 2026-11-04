CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __rows TEXT[];
BEGIN
    SELECT array_agg(
        format( '%s|%s|%s|%s|%s|%s'
            , k.account_name
            , k.key_kind
            , CASE WHEN k.key_auth IS NULL THEN NULL ELSE hive.public_key_to_string( k.key_auth ) END
            , k.account_auth
            , k.weight_threshold
            , k.w )
        ORDER BY k.ordinality )
    FROM hive.get_genesis_keyauths() WITH ORDINALITY k
    INTO __rows;

    -- miners and null get init_genesis' locked authority: threshold 1, no key, no account
    ASSERT __rows = ARRAY[
          'steem|OWNER|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'steem|ACTIVE|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'steem|POSTING|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'steem|MEMO|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'initminer|OWNER|STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX||1|1'
        , 'initminer|ACTIVE|STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX||1|1'
        , 'initminer|POSTING|STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX||1|1'
        , 'initminer|MEMO|STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX||1|1'
        , 'temp|OWNER|||0|0'
        , 'temp|ACTIVE|||0|0'
        , 'temp|POSTING|||0|0'
        , 'miners|OWNER|||1|0'
        , 'miners|ACTIVE|||1|0'
        , 'miners|POSTING|||1|0'
        , 'null|OWNER|||1|0'
        , 'null|ACTIVE|||1|0'
        , 'null|POSTING|||1|0'
        , 'miners|MEMO|STM1111111111111111111111111111111114T1Anm||0|0'
        , 'null|MEMO|STM1111111111111111111111111111111114T1Anm||0|0'
        , 'temp|MEMO|STM1111111111111111111111111111111114T1Anm||0|0'
    ], format( 'Unexpected genesis authorities: %s', __rows );

    ASSERT ( SELECT COUNT(*) FROM hive.get_genesis_keyauths()
             WHERE account_name IN ( 'miners', 'null' )
               AND key_kind IN ( 'OWNER', 'ACTIVE', 'POSTING' )
               AND weight_threshold = 1 AND key_auth IS NULL AND account_auth IS NULL AND w = 0 ) = 6
        , 'miners and null lack their locked OWNER/ACTIVE/POSTING authorities';
END;
$BODY$
;
