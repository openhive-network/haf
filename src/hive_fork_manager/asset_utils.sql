DROP TYPE IF EXISTS hive.asset_symbol_info CASCADE;
CREATE TYPE hive.asset_symbol_info AS
(
  precision SMALLINT, -- Precision of assets
  nai       INT,      -- Type of asset symbol used in the operation
  is_liquid BOOLEAN,  -- True if given asset_symbol represents liquid version of asset
  is_native BOOLEAN   -- True if given asset_symbol represents native Hive asset
);

CREATE OR REPLACE FUNCTION hive.decode_asset_symbol(IN _symbol hive.asset_symbol)
RETURNS hive.asset_symbol_info 
AS 'MODULE_PATHNAME', 'decode_asset_symbol' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION hive.get_paired_symbol(IN _symbol hive.asset_symbol)
RETURNS hive.asset_symbol
AS 'MODULE_PATHNAME', 'get_paired_asset_symbol' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION hive.asset_symbol_to_nai_string(IN _symbol hive.asset_symbol)
RETURNS TEXT 
AS 'MODULE_PATHNAME', 'asset_symbol_to_nai_string' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION hive.asset_symbol_from_nai_string(IN _nai_string TEXT, IN _precision SMALLINT)
RETURNS hive.asset_symbol
AS 'MODULE_PATHNAME', 'asset_symbol_from_nai_string' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
