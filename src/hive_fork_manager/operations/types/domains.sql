CREATE DOMAIN hive.account_name_type AS VARCHAR(16);

CREATE DOMAIN hive.permlink AS VARCHAR(255);

CREATE DOMAIN hive.comment_title AS VARCHAR(255);

CREATE DOMAIN hive.memo AS VARCHAR(2048);

CREATE DOMAIN hive.public_key_type AS bytea;

CREATE DOMAIN hive.weight_type AS int4; -- uint16_t: 2 byte, but unsigned (int4)

CREATE DOMAIN hive.share_type AS int8;

CREATE DOMAIN hive.ushare_type AS NUMERIC;

CREATE DOMAIN hive.signature_type AS bytea;

CREATE DOMAIN hive.block_id_type AS bytea;

CREATE DOMAIN hive.transaction_id_type AS bytea;

CREATE DOMAIN hive.digest_type AS bytea;

CREATE DOMAIN hive.custom_id_type AS VARCHAR(32);

CREATE DOMAIN hive.asset_symbol AS int8; -- uint32_t: 4 byte, but unsigned (int8)

CREATE DOMAIN hive.proposal_subject AS VARCHAR(80);
