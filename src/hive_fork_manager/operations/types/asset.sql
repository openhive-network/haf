CREATE TYPE hive.asset AS (
  amount hive.share_type,
  symbol hive.asset_symbol
);

CREATE TYPE hive.price AS (
  base hive.asset,
  quote hive.asset
);


CREATE TYPE hive.legacy_hive_asset_symbol_type AS (
  ser NUMERIC
);

CREATE TYPE hive.legacy_hive_asset AS (
  amount hive.share_type,
  symbol hive.legacy_hive_asset_symbol_type
);
