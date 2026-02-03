-- Asset Unique ID encoding/decoding functions
-- Bit layout (128 bits):
--   Bits 64-127: operation_id (64 bits)
--   Bits 32-63:  NAI (Numeric Asset Identifier) (32 bits)
--   Bits 0-31:   subsequent_no (32 bits)

-- Encoder: Generate a unique asset ID from components
-- Raises exception if subsequent_no exceeds uint32_t max (4294967295)
CREATE OR REPLACE FUNCTION hafd.generate_asset_unique_id(
    _asset_symbol hafd.asset_symbol,
    _operation_id BIGINT,
    _subsequent_no BIGINT
)
    RETURNS hafd.asset_unique_id
    IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME', 'generate_asset_unique_id' LANGUAGE C;

-- Decoder: Extract operation_id from asset_unique_id
CREATE OR REPLACE FUNCTION hafd.asset_unique_id_to_operation_id(_id hafd.asset_unique_id)
    RETURNS BIGINT
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'asset_unique_id_to_operation_id' LANGUAGE C;

-- Decoder: Extract asset_symbol from asset_unique_id
-- Note: Returns asset_symbol reconstructed from NAI with precision 0
CREATE OR REPLACE FUNCTION hafd.asset_unique_id_to_asset_symbol(_id hafd.asset_unique_id)
    RETURNS hafd.asset_symbol
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'asset_unique_id_to_asset_symbol' LANGUAGE C;

-- Decoder: Extract subsequent_no from asset_unique_id
CREATE OR REPLACE FUNCTION hafd.asset_unique_id_to_subsequent_no(_id hafd.asset_unique_id)
    RETURNS BIGINT
    IMMUTABLE PARALLEL SAFE LEAKPROOF
AS 'MODULE_PATHNAME', 'asset_unique_id_to_subsequent_no' LANGUAGE C;
