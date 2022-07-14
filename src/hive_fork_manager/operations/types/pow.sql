CREATE TYPE pow AS (
  worker hive.public_key_type,
  input hive.digest_type,
  "signature" hive.signature_type,
  work hive.digest_type
);