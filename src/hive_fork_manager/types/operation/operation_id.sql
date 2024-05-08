-- contains encoding from operation id to block num, type_id, and seq. in block

CREATE OR REPLACE FUNCTION hive.operation_id_to_block_num( _id hive.operations.id%TYPE )
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS
$BEGIN$
BEGIN
    RETURN _id >> 32;
END;
$BEGIN$;

CREATE OR REPLACE FUNCTION hive.operation_id_to_type_id( _id hive.operations.id%TYPE )
    RETURNS INTEGER
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BEGIN$
BEGIN
    RETURN _id & 0xFF;
END;
$BEGIN$;

CREATE OR REPLACE FUNCTION hive.operation_id_to_pos( _id hive.operations.id%TYPE )
    RETURNS INTEGER
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BEGIN$
BEGIN
    RETURN ( _id >> 8 ) & 0xFFFFFF;
END;
$BEGIN$;

CREATE OR REPLACE FUNCTION hive.operation_id( _block_num INTEGER, _type INTEGER, _pos_in_block INTEGER )
    RETURNS BIGINT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BEGIN$
BEGIN
    RETURN ( _block_num::BIGINT << 32 ) | ( _pos_in_block::BIGINT << 8 ) | _type;
END;
$BEGIN$;
