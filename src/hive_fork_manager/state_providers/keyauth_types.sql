
DROP TYPE IF EXISTS hive.key_type CASCADE;
CREATE TYPE hive.key_type AS ENUM( 'OWNER', 'ACTIVE', 'POSTING', 'MEMO', 'WITNESS_SIGNING');

DROP TYPE IF EXISTS hive.keyauth_record_type CASCADE;
CREATE TYPE hive.keyauth_record_type AS
(
    account_name TEXT
    , key_kind hive.key_type
    , key_auth BYTEA
    , account_auth TEXT
    , weight_threshold INTEGER
    , w INTEGER
);

DROP TYPE IF EXISTS hive.keyauth_c_record_type CASCADE;
CREATE TYPE hive.keyauth_c_record_type AS
(
    account_name TEXT
    , authority_c_kind INTEGER
    , key_auth BYTEA
    , account_auth TEXT
    , weight_threshold INTEGER
    , w INTEGER
);