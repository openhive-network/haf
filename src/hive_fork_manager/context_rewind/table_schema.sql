
CREATE TABLE IF NOT EXISTS hive.verify_table_schema(
    table_name TEXT NOT NULL,
    table_schema TEXT NOT NULL,
    table_schema_hash UUID,
    columns_hash UUID,
    constraints_hash UUID,
    indexes_hash UUID,
    table_columns TEXT NOT NULL,
    table_constraints TEXT NOT NULL,
    table_indexes TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS hive.table_schema(
    schema_name TEXT NOT NULL,
    schema_hash UUID NOT NULL
);

CREATE TABLE IF NOT EXISTS hive.verified_tables_list(
    table_name TEXT NOT NULL
);

INSERT INTO hive.verified_tables_list VALUES 
('blocks'),
('irreversible_data'),
('transactions'),
('transactions_multisig'),
('operation_types'),
('operations'),
('applied_hardforks'),
('accounts'),
('account_operations'),
('fork'),
('blocks_reversible'),
('blocks_reversible'),
('transactions_multisig_reversible'),
('operations_reversible'),
('accounts_reversible'),
('account_operations_reversible'),
('applied_hardforks_reversible'),
('contexts');



