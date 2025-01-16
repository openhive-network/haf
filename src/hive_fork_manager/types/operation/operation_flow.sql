-- Cast functions for the hive operation type (communication between hafd.operation and internal data type)

CREATE OR REPLACE FUNCTION hafd._operation_in(
  cstring
) RETURNS hafd.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_in';

CREATE OR REPLACE FUNCTION hafd._operation_out(
  hafd.operation
) RETURNS cstring LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_out';


CREATE OR REPLACE FUNCTION hafd._operation_bin_in_internal(
  internal
) RETURNS hafd.operation LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_in_internal';


CREATE OR REPLACE FUNCTION hafd._operation_bin_in(
  bytea
) RETURNS hafd.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_in';

CREATE OR REPLACE FUNCTION hafd._operation_bin_out(
  hafd.operation
) RETURNS bytea LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_out';

CREATE OR REPLACE FUNCTION hafd._operation_to_jsonb(
  hafd.operation
) RETURNS jsonb LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_jsonb';

CREATE OR REPLACE FUNCTION hafd._operation_from_jsonb(
  jsonb
) RETURNS hafd.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_from_jsonb';

CREATE OR REPLACE FUNCTION hafd.operation_to_jsontext(
  hafd.operation
) RETURNS text LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_jsontext';

CREATE OR REPLACE FUNCTION hafd.operation_from_jsontext(
  text
) RETURNS hafd.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_from_jsontext';

CREATE OR REPLACE FUNCTION hafd._operation_eq(
  hafd.operation, hafd.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_eq';

CREATE OR REPLACE FUNCTION hafd._operation_ne(
  hafd.operation, hafd.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_ne';

CREATE OR REPLACE FUNCTION hafd._operation_lt(
  hafd.operation, hafd.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_lt';

CREATE OR REPLACE FUNCTION hafd._operation_le(
  hafd.operation, hafd.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_le';

CREATE OR REPLACE FUNCTION hafd._operation_gt(
  hafd.operation, hafd.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_gt';

CREATE OR REPLACE FUNCTION hafd._operation_ge(
  hafd.operation, hafd.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_ge';

CREATE OR REPLACE FUNCTION hafd._operation_cmp(
  hafd.operation, hafd.operation
) RETURNS int4 LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_cmp';

CREATE OR REPLACE FUNCTION hafd.operation_type_name(
  hafd.operation
) RETURNS TEXT LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_type_name';
