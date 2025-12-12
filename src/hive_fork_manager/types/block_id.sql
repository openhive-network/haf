-- block_id encoding: (block_num << 32) | fork_id
-- Upper 32 bits = block_num
-- Lower 32 bits = fork_id

CREATE DOMAIN hafd.block_id AS BIGINT;

CREATE OR REPLACE FUNCTION hafd.make_block_id( _block_num INTEGER, _fork_id BIGINT )
    RETURNS hafd.block_id
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'make_block_id' LANGUAGE C;

CREATE OR REPLACE FUNCTION hafd.block_id_to_num( _id hafd.block_id )
    RETURNS INTEGER
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'block_id_to_num' LANGUAGE C;

CREATE OR REPLACE FUNCTION hafd.block_id_to_fork( _id hafd.block_id )
    RETURNS BIGINT
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'block_id_to_fork' LANGUAGE C;
