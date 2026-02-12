-- contains encoding from operation id to block num and seq. in block
-- Encoding: || 32b block_num | 32b pos_in_block ||
-- Type is NOT encoded in operation_id - it is stored as a separate column.

CREATE OR REPLACE FUNCTION hafd.operation_id_to_block_num( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'operation_id_to_block_num' LANGUAGE C;

CREATE OR REPLACE FUNCTION hafd.operation_id_to_pos( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'operation_id_to_pos' LANGUAGE C;


CREATE OR REPLACE FUNCTION hafd.operation_id( _block_num INTEGER, _pos_in_block INTEGER )
    RETURNS BIGINT
    IMMUTABLE PARALLEL SAFE
AS 'MODULE_PATHNAME', 'to_operation_id' LANGUAGE C;
