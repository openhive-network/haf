-- Cast functions for the hive operation type (communication between hive_data.operation and internal data type)

CREATE OR REPLACE FUNCTION hive_data._operation_in(
  cstring
) RETURNS hive_data.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_in';

CREATE OR REPLACE FUNCTION hive_data._operation_out(
  hive_data.operation
) RETURNS cstring LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_out';


CREATE OR REPLACE FUNCTION hive_data._operation_bin_in_internal(
  internal
) RETURNS hive_data.operation LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_in_internal';


CREATE OR REPLACE FUNCTION hive_data._operation_bin_in(
  bytea
) RETURNS hive_data.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_in';

CREATE OR REPLACE FUNCTION hive_data._operation_bin_out(
  hive_data.operation
) RETURNS bytea LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_out';

CREATE OR REPLACE FUNCTION hive_data._operation_to_jsonb(
  hive_data.operation
) RETURNS jsonb LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_jsonb';

CREATE OR REPLACE FUNCTION hive_data._operation_from_jsonb(
  jsonb
) RETURNS hive_data.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_from_jsonb';

CREATE OR REPLACE FUNCTION hive_data.operation_to_jsontext(
  hive_data.operation
) RETURNS text LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_jsontext';

CREATE OR REPLACE FUNCTION hive_data.operation_from_jsontext(
  text
) RETURNS hive_data.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_from_jsontext';

CREATE OR REPLACE FUNCTION hive_data._operation_eq(
  hive_data.operation, hive_data.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_eq';

CREATE OR REPLACE FUNCTION hive_data._operation_ne(
  hive_data.operation, hive_data.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_ne';

CREATE OR REPLACE FUNCTION hive_data._operation_lt(
  hive_data.operation, hive_data.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_lt';

CREATE OR REPLACE FUNCTION hive_data._operation_le(
  hive_data.operation, hive_data.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_le';

CREATE OR REPLACE FUNCTION hive_data._operation_gt(
  hive_data.operation, hive_data.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_gt';

CREATE OR REPLACE FUNCTION hive_data._operation_ge(
  hive_data.operation, hive_data.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_ge';

CREATE OR REPLACE FUNCTION hive_data._operation_cmp(
  hive_data.operation, hive_data.operation
) RETURNS int4 LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_cmp';

CREATE OR REPLACE FUNCTION hive_data.operation_type_name(
  hive_data.operation
) RETURNS TEXT LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_type_name';
