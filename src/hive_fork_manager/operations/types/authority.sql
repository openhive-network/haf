CREATE TYPE hive.authority AS (
  weight_treshold int8, -- uint32_t: 4 byte, but unsigned (int8)
  account_auths hstore, -- hive.account_name_type => hive.weight_type
  key_auths hstore -- hive.public_key_type => hive.weight_type
);

