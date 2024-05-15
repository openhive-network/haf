-- contains encoding from operation id to block num, type_id, and seq. in block

CREATE OR REPLACE FUNCTION hive.operation_id_to_block_num( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE
AS 'MODULE_PATHNAME', 'operation_id_to_block_num' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.operation_id_to_type_id( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE
AS 'MODULE_PATHNAME', 'operation_id_to_type_id' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.operation_id_to_pos( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE
AS 'MODULE_PATHNAME', 'operation_id_to_pos' LANGUAGE C;


CREATE OR REPLACE FUNCTION hive.operation_id( _block_num INTEGER, _type INTEGER, _pos_in_block INTEGER )
    RETURNS BIGINT
    IMMUTABLE
AS 'MODULE_PATHNAME', 'to_operation_id' LANGUAGE C;


