DO $$
BEGIN
    CREATE ROLE hived_group WITH NOLOGIN;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hived_group role already exists';
END
$$;

DO $$
BEGIN
    CREATE ROLE hive_applications_group WITH NOLOGIN;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hive_applications_group role already exists';
END
$$;

ALTER TABLE hive.blocks OWNER TO hived_group;
ALTER TABLE hive.transactions OWNER TO hived_group;
ALTER TABLE hive.operations OWNER TO hived_group;
ALTER TABLE hive.transactions_multisig OWNER TO hived_group;
ALTER TABLE hive.accounts OWNER TO hived_group;
ALTER TABLE hive.account_operations OWNER TO hived_group;
ALTER TABLE hive.irreversible_data OWNER TO hived_group;
ALTER TABLE hive.blocks_reversible OWNER TO hived_group;
ALTER TABLE hive.transactions_reversible OWNER TO hived_group;
ALTER TABLE hive.operations_reversible OWNER TO hived_group;
ALTER TABLE hive.transactions_multisig_reversible OWNER TO hived_group;
ALTER TABLE hive.accounts_reversible OWNER TO hived_group;
ALTER TABLE hive.account_operations_reversible OWNER TO hived_group;

-- generic protection for tables in hive schema
-- 1. hived_group allow to edit every table in hive schema
-- 2. hive_applications_group can ready every table in hive schema
-- 3. hive_applications_group can modify hive.contexts, hive.registered_tables, hive.triggers, hive.state_providers_registered
GRANT ALL ON SCHEMA hive to hived_group, hive_applications_group;
GRANT ALL ON ALL SEQUENCES IN SCHEMA hive TO hived_group, hive_applications_group;
GRANT ALL ON  ALL TABLES IN SCHEMA hive TO hived_group;
GRANT SELECT ON ALL TABLES IN SCHEMA hive TO hive_applications_group;
GRANT ALL ON hive.contexts TO hive_applications_group;
GRANT ALL ON hive.registered_tables TO hive_applications_group;
GRANT ALL ON hive.triggers TO hive_applications_group;
GRANT ALL ON hive.state_providers_registered TO hive_applications_group;

-- protect an application rows aginst other applications
ALTER TABLE hive.contexts ENABLE ROW LEVEL SECURITY;
CREATE POLICY dp_hive_context ON hive.contexts FOR ALL USING ( owner = current_user );
CREATE POLICY sp_hived_hive_context ON hive.contexts FOR SELECT TO hived_group USING( TRUE );
CREATE POLICY sp_applications_hive_context ON hive.contexts FOR SELECT TO hive_applications_group USING( owner = current_user );
CREATE POLICY sp_applications_hive_state_providers ON hive.state_providers_registered FOR SELECT TO hive_applications_group USING( owner = current_user );

ALTER TABLE hive.registered_tables ENABLE ROW LEVEL SECURITY;
CREATE POLICY policy_hive_registered_tables ON hive.registered_tables FOR ALL USING ( owner = current_user );

ALTER TABLE hive.triggers ENABLE ROW LEVEL SECURITY;
CREATE POLICY policy_hive_triggers ON hive.triggers FOR ALL USING ( owner = current_user );

ALTER TABLE hive.state_providers_registered ENABLE ROW LEVEL SECURITY;
CREATE POLICY dp_state_providers_registered ON hive.state_providers_registered FOR ALL USING ( owner = current_user );

-- protect api
-- 1. only hived_group and hive_applications_group can invoke functions from hive schema
-- 2. hived_group can use only hived_api
-- 3. hive_applications_group can use every functions from hive schema except hived_api
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA hive FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hive TO hive_applications_group;

GRANT EXECUTE ON FUNCTION
      hive.back_from_fork( INT )
    , hive.push_block( hive.blocks, hive.transactions[], hive.transactions_multisig[], hive.operations[], hive.accounts[], hive.account_operations[] )
    , hive.set_irreversible( INT )
    , hive.end_massive_sync( INTEGER )
    , disable_indexes_of_irreversible()
    , enable_indexes_of_irreversible()
    , hive.save_and_drop_indexes_constraints( in _schema TEXT, in _table TEXT )
    , hive.save_and_drop_indexes_foreign_keys( in _table_schema TEXT, in _table_name TEXT )
    , hive.restore_indexes_constraints( in _table_name TEXT )
    , hive.restore_foreign_keys( in _table_name TEXT )
    , hive.copy_blocks_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_transactions_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_operations_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_signatures_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_accounts_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_account_operations_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    , hive.remove_unecessary_events( _new_irreversible_block INT )
    , hive.register_table( _table_schema TEXT,  _table_name TEXT, _context_name TEXT ) -- needs to alter tables when indexes are disabled
    , hive.chceck_constrains( _table_schema TEXT,  _table_name TEXT )
    , hive.register_state_provider_tables( _context hive.context_name )
    , hive.app_state_providers_update( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    , hive.app_state_provider_import( _state_provider hive.state_providers, _context hive.context_name )
    , hive.connect( _git_sha TEXT, _block_num hive.blocks.num%TYPE )
    , hive.remove_inconsistend_irreversible_data()
    , hive.disable_indexes_of_reversible()
    , hive.enable_indexes_of_reversible()
TO hived_group;

REVOKE EXECUTE ON FUNCTION
      hive.back_from_fork( INT )
    , hive.push_block( hive.blocks, hive.transactions[], hive.transactions_multisig[], hive.operations[], hive.accounts[], hive.account_operations[] )
    , hive.set_irreversible( INT )
    , hive.end_massive_sync( INTEGER )
    , hive.copy_blocks_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_transactions_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_operations_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_signatures_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    , hive.remove_unecessary_events( _new_irreversible_block INT )
FROM hive_applications_group;

