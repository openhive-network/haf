CREATE TYPE hafd.key_type AS ENUM( 'OWNER', 'ACTIVE', 'POSTING', 'MEMO', 'WITNESS_SIGNING');

CREATE TYPE hafd.key_type_c_int_to_enum AS
(
      account_name TEXT
    , key_kind hafd.key_type
    , key_auth BYTEA
    , account_auth TEXT
    , weight_threshold INTEGER
    , w INTEGER
);
