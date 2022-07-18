CREATE TYPE hive._account_auths_authority AS (
  "first" hive.account_name_type,
  second hive.weight_type
);

CREATE TYPE hive._key_auths_authority AS (
  "first" hive.public_key_type,
  second hive.weight_type
);

CREATE TYPE hive.authority AS (
  weight_treshold int8, -- uint32_t: 4 byte, but unsigned (int8)
  account_auths hive._account_auths_authority[],
  key_auths hive._key_auths_authority[]
);

