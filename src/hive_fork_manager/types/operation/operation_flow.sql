-- Cast functions for the hive operation type (communication between hive.operation and internal data type)

CREATE OR REPLACE FUNCTION hive._operation_in(
  cstring
) RETURNS hive.operation LANGUAGE c IMMUTABLE STRICT
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so',
'operation_in';

CREATE OR REPLACE FUNCTION hive._operation_out(
  hive.operation
) RETURNS cstring LANGUAGE c IMMUTABLE STRICT
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so',
'operation_out';


CREATE OR REPLACE FUNCTION hive._operation_bin_in_internal(
  internal
) RETURNS hive.operation LANGUAGE C IMMUTABLE STRICT
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so',
'operation_bin_in_internal';


CREATE OR REPLACE FUNCTION hive._operation_bin_in(
  bytea
) RETURNS hive.operation LANGUAGE c IMMUTABLE STRICT
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so',
'operation_bin_in';

CREATE OR REPLACE FUNCTION hive._operation_bin_out(
  hive.operation
) RETURNS bytea LANGUAGE c IMMUTABLE STRICT
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so',
'operation_bin_out';


CREATE OR REPLACE FUNCTION hive._operation_eq(
  hive.operation, hive.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so',
'operation_eq';

CREATE OR REPLACE FUNCTION hive._operation_ne(
  hive.operation, hive.operation
) RETURNS bool LANGUAGE C IMMUTABLE STRICT
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so',
'operation_ne';
