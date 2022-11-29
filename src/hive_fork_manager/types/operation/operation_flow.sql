-- Cast functions for the hive operation type (communication between hive.operation and internal data type)

CREATE OR REPLACE FUNCTION hive._operation_in(
  cstring
) RETURNS hive.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_in';

CREATE OR REPLACE FUNCTION hive._operation_out(
  hive.operation
) RETURNS cstring LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_out';


CREATE OR REPLACE FUNCTION hive._operation_bin_in_internal(
  internal
) RETURNS hive.operation LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_in_internal';


CREATE OR REPLACE FUNCTION hive._operation_bin_in(
  bytea
) RETURNS hive.operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_in';

CREATE OR REPLACE FUNCTION hive._operation_bin_out(
  hive.operation
) RETURNS bytea LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_bin_out';


CREATE OR REPLACE FUNCTION hive._operation_eq(
  hive.operation, hive.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_eq';

CREATE OR REPLACE FUNCTION hive._operation_ne(
  hive.operation, hive.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_ne';

CREATE OR REPLACE FUNCTION hive._operation_lt(
  hive.operation, hive.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_lt';

CREATE OR REPLACE FUNCTION hive._operation_le(
  hive.operation, hive.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_le';

CREATE OR REPLACE FUNCTION hive._operation_gt(
  hive.operation, hive.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_gt';

CREATE OR REPLACE FUNCTION hive._operation_ge(
  hive.operation, hive.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_ge';

CREATE OR REPLACE FUNCTION hive._operation_cmp(
  hive.operation, hive.operation
) RETURNS int4 LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_cmp';

CREATE FUNCTION hive._operation_hash(
  hive.operation
) RETURNS int4 LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_hash';
