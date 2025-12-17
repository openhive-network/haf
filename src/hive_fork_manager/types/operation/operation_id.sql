-- contains encoding from operation id to block num, type_id, and seq. in block

CREATE OR REPLACE FUNCTION hafd.operation_id_to_block_num( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'operation_id_to_block_num' LANGUAGE C;

CREATE OR REPLACE FUNCTION hafd.operation_id_to_type_id( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'operation_id_to_type_id' LANGUAGE C;

CREATE OR REPLACE FUNCTION hafd.operation_id_to_pos( _id BIGINT )
    RETURNS INTEGER
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'operation_id_to_pos' LANGUAGE C;


CREATE OR REPLACE FUNCTION hafd.operation_id( _block_num INTEGER, _type INTEGER, _pos_in_block INTEGER )
    RETURNS BIGINT
    IMMUTABLE PARALLEL SAFE
AS 'MODULE_PATHNAME', 'to_operation_id' LANGUAGE C;

CREATE OR REPLACE FUNCTION hafd.operation_id(_block_id hafd.block_id, _seq INT, _type SMALLINT)
RETURNS BIGINT
IMMUTABLE PARALLEL SAFE AS $$
    SELECT (hafd.block_id_to_num(_block_id)::BIGINT << 32) | (_seq << 8) | _type;
$$ LANGUAGE SQL;
