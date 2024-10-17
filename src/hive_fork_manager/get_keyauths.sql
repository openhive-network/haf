DROP FUNCTION IF EXISTS hive.get_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_keyauths_wrapper(IN _operation_body hive_data.operation)
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_genesis_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_genesis_keyauths_wrapper()
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_genesis_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_hf09_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_hf09_keyauths_wrapper()
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_hf09_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_hf21_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_hf21_keyauths_wrapper()
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_hf21_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_hf24_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_hf24_keyauths_wrapper()
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_hf24_keyauths_wrapped' LANGUAGE C;


CREATE OR REPLACE FUNCTION hive.public_key_to_string(p_key BYTEA)
RETURNS TEXT
AS 'MODULE_PATHNAME', 'public_key_to_string' LANGUAGE C;




DROP FUNCTION IF EXISTS hive.is_keyauths_operation;
