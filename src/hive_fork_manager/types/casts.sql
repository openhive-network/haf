CREATE OR REPLACE FUNCTION hive._operation_to_comment_operation(
  hive.operation
) RETURNS hive.comment_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_operation';

CREATE CAST (hive.operation AS hive.comment_operation)
  WITH FUNCTION hive._operation_to_comment_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_comment_options_operation(
  hive.operation
) RETURNS hive.comment_options_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_options_operation';

CREATE CAST (hive.operation AS hive.comment_options_operation)
  WITH FUNCTION hive._operation_to_comment_options_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_vote_operation(
  hive.operation
) RETURNS hive.vote_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_vote_operation';

CREATE CAST (hive.operation AS hive.vote_operation)
  WITH FUNCTION hive._operation_to_vote_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_witness_set_properties_operation(
  hive.operation
) RETURNS hive.witness_set_properties_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_witness_set_properties_operation';

CREATE CAST (hive.operation AS hive.witness_set_properties_operation)
  WITH FUNCTION hive._operation_to_witness_set_properties_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_create_operation(
  hive.operation
) RETURNS hive.account_create_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_create_operation';

CREATE CAST (hive.operation AS hive.account_create_operation)
  WITH FUNCTION hive._operation_to_account_create_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_create_with_delegation_operation(
  hive.operation
) RETURNS hive.account_create_with_delegation_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_create_with_delegation_operation';

CREATE CAST (hive.operation AS hive.account_create_with_delegation_operation)
  WITH FUNCTION hive._operation_to_account_create_with_delegation_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_update2_operation(
  hive.operation
) RETURNS hive.account_update2_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_update2_operation';

CREATE CAST (hive.operation AS hive.account_update2_operation)
  WITH FUNCTION hive._operation_to_account_update2_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_update_operation(
  hive.operation
) RETURNS hive.account_update_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_update_operation';

CREATE CAST (hive.operation AS hive.account_update_operation)
  WITH FUNCTION hive._operation_to_account_update_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_witness_proxy_operation(
  hive.operation
) RETURNS hive.account_witness_proxy_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_witness_proxy_operation';

CREATE CAST (hive.operation AS hive.account_witness_proxy_operation)
  WITH FUNCTION hive._operation_to_account_witness_proxy_operation
  AS ASSIGNMENT;
