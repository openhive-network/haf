-- domains

DROP DOMAIN IF EXISTS hafd.account_name_type CASCADE;
CREATE DOMAIN hafd.account_name_type AS VARCHAR(16);

DROP DOMAIN IF EXISTS hafd.permlink CASCADE;
CREATE DOMAIN hafd.permlink AS VARCHAR(255);

DROP DOMAIN IF EXISTS hafd.comment_title CASCADE;
CREATE DOMAIN hafd.comment_title AS VARCHAR(255);

DROP DOMAIN IF EXISTS hafd.memo CASCADE;
CREATE DOMAIN hafd.memo AS VARCHAR(2048);

DROP DOMAIN IF EXISTS hafd.public_key_type CASCADE;
CREATE DOMAIN hafd.public_key_type AS VARCHAR;

DROP DOMAIN IF EXISTS hafd.weight_type CASCADE;
CREATE DOMAIN hafd.weight_type AS int4; -- uint16_t: 2 byte, but unsigned (int4)

DROP DOMAIN IF EXISTS hafd.share_type CASCADE;
CREATE DOMAIN hafd.share_type AS int8;

DROP DOMAIN IF EXISTS hafd.ushare_type CASCADE;
CREATE DOMAIN hafd.ushare_type AS NUMERIC;

DROP DOMAIN IF EXISTS hafd.signature_type CASCADE;
CREATE DOMAIN hafd.signature_type AS bytea;

DROP DOMAIN IF EXISTS hafd.block_id_type CASCADE;
CREATE DOMAIN hafd.block_id_type AS bytea;

DROP DOMAIN IF EXISTS hafd.transaction_id_type CASCADE;
CREATE DOMAIN hafd.transaction_id_type AS bytea;

DROP DOMAIN IF EXISTS hafd.digest_type CASCADE;
CREATE DOMAIN hafd.digest_type AS bytea;

DROP DOMAIN IF EXISTS hafd.custom_id_type CASCADE;
CREATE DOMAIN hafd.custom_id_type AS VARCHAR(32);

DROP DOMAIN IF EXISTS hafd.asset_symbol CASCADE;
CREATE DOMAIN hafd.asset_symbol AS int8; -- uint32_t: 4 byte, but unsigned (int8)

DROP DOMAIN IF EXISTS hafd.proposal_subject CASCADE;
CREATE DOMAIN hafd.proposal_subject AS VARCHAR(80);
