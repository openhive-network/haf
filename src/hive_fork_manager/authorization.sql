--- Helper function able to verify roles authority relationship and returns true when _role_to_check has granted rights to impersonate as _required_role.
CREATE OR REPLACE FUNCTION hive.can_impersonate(_role_to_check IN TEXT, _required_role IN TEXT)
RETURNS BOOLEAN
LANGUAGE 'plpgsql'
STABLE
AS
$$
DECLARE
  __retval BOOLEAN := FALSE;
BEGIN
  --- Trivial case
  IF (_role_to_check = _required_role) THEN
    RETURN TRUE;
  END IF;

  WITH RECURSIVE role_membership AS MATERIALIZED
  (
     SELECT oid FROM pg_roles WHERE rolname = _role_to_check
     UNION
     SELECT m.roleid
     FROM role_membership rm
     JOIN pg_auth_members m ON m.member = rm.oid
  ),membership AS
  (
    SELECT oid::regrole::text AS rolename FROM role_membership
  )
  SELECT into __retval EXISTS(SELECT NULL FROM membership m WHERE m.rolename = _required_role);

--raise notice '_role_to_check: %, _required_role: %', _role_to_check, _required_role;
  RETURN __retval;
END
$$
;


ALTER TABLE hive.operation_types OWNER TO hived_group;
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
ALTER TABLE hive.applied_hardforks OWNER TO hived_group;
ALTER TABLE hive.applied_hardforks_reversible OWNER TO hived_group;
ALTER TABLE hive.write_ahead_log_state OWNER TO hived_group;

-- generic protection for tables in hive schema
-- 1. hived_group allow to edit every table in hive schema
-- 2. hive_applications_group can ready every table in hive schema
-- 3. hive_applications_group can modify hive.contexts, hive.registered_tables, hive.triggers, hive.state_providers_registered
GRANT ALL ON SCHEMA hive to hived_group, hive_applications_group;
GRANT ALL ON ALL SEQUENCES IN SCHEMA hive TO hived_group, hive_applications_group;
GRANT ALL ON  ALL TABLES IN SCHEMA hive TO hived_group;
GRANT SELECT ON ALL TABLES IN SCHEMA hive TO hive_applications_group;
GRANT ALL ON hive.contexts TO hive_applications_group;
GRANT ALL ON hive.contexts_attachment TO hive_applications_group;
GRANT ALL ON hive.registered_tables TO hive_applications_group;
GRANT ALL ON hive.triggers TO hive_applications_group;
GRANT ALL ON hive.state_providers_registered TO hive_applications_group;

-- protect an application rows aginst other applications
REVOKE UPDATE( is_forking, owner ) ON hive.contexts FROM GROUP hive_applications_group;
ALTER TABLE hive.contexts ENABLE ROW LEVEL SECURITY;

REVOKE UPDATE( owner ) ON hive.contexts_attachment FROM GROUP hive_applications_group;
ALTER TABLE hive.contexts_attachment ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dp_hive_context ON hive.contexts CASCADE;
CREATE POLICY dp_hive_context ON hive.contexts FOR INSERT WITH CHECK ( current_user = owner );

DROP POLICY IF EXISTS dp_hive_contexts_attachment ON hive.contexts_attachment CASCADE;
CREATE POLICY dp_hive_contexts_attachment ON hive.contexts_attachment FOR INSERT WITH CHECK ( current_user = owner );

DROP POLICY IF EXISTS sp_hived_hive_context ON hive.contexts CASCADE;
CREATE POLICY sp_hived_hive_context ON hive.contexts FOR SELECT TO hived_group USING( TRUE );

DROP POLICY IF EXISTS sp_hived_hive_contexts_attachment ON hive.contexts_attachment CASCADE;
CREATE POLICY sp_hived_hive_contexts_attachment ON hive.contexts_attachment FOR SELECT TO hived_group USING( TRUE );

DROP POLICY IF EXISTS sp_applications_hive_context ON hive.contexts CASCADE;
CREATE POLICY sp_applications_hive_context ON hive.contexts FOR SELECT TO hive_applications_group USING( TRUE );

DROP POLICY IF EXISTS sp_applications_hive_contexts_attachment ON hive.contexts_attachment CASCADE;
CREATE POLICY sp_applications_hive_contexts_attachment ON hive.contexts_attachment FOR SELECT TO hive_applications_group USING( TRUE );

DROP POLICY IF EXISTS sp_applications_update_hive_context ON hive.contexts CASCADE;
CREATE POLICY sp_applications_update_hive_context ON hive.contexts FOR UPDATE TO hive_applications_group USING( TRUE ) WITH CHECK( hive.can_impersonate(current_user, owner) ) ;

DROP POLICY IF EXISTS sp_applications_update_hive_contexts_attachment ON hive.contexts_attachment CASCADE;
CREATE POLICY sp_applications_update_hive_contexts_attachment ON hive.contexts_attachment FOR UPDATE TO hive_applications_group USING( TRUE ) WITH CHECK( hive.can_impersonate(current_user, owner) ) ;

DROP POLICY IF EXISTS sp_applications_delete_hive_context ON hive.contexts CASCADE;
CREATE POLICY sp_applications_delete_hive_context ON hive.contexts FOR DELETE TO hive_applications_group USING( hive.can_impersonate(current_user, owner) );

DROP POLICY IF EXISTS sp_applications_delete_hive_contexts_attachment ON hive.contexts_attachment CASCADE;
CREATE POLICY sp_applications_delete_hive_contexts_attachment ON hive.contexts_attachment FOR DELETE TO hive_applications_group USING( hive.can_impersonate(current_user, owner) );

DROP POLICY IF EXISTS sp_applications_hive_state_providers ON hive.state_providers_registered CASCADE;
CREATE POLICY sp_applications_hive_state_providers ON hive.state_providers_registered FOR SELECT TO hive_applications_group USING( hive.can_impersonate(current_user, owner) );

ALTER TABLE hive.registered_tables ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS policy_hive_registered_tables ON hive.registered_tables CASCADE;
CREATE POLICY policy_hive_registered_tables ON hive.registered_tables FOR ALL USING ( hive.can_impersonate(current_user, owner) );

ALTER TABLE hive.triggers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS policy_hive_triggers ON hive.triggers CASCADE;
CREATE POLICY policy_hive_triggers ON hive.triggers FOR ALL USING ( hive.can_impersonate(current_user, owner) );

ALTER TABLE hive.state_providers_registered ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dp_state_providers_registered ON hive.state_providers_registered CASCADE;
CREATE POLICY dp_state_providers_registered ON hive.state_providers_registered FOR ALL USING ( hive.can_impersonate(current_user, owner) );


-- protect api
-- 1. only hived_group and hive_applications_group can invoke functions from hive schema
-- 2. hived_group can use only hived_api
-- 3. hive_applications_group can use every functions from hive schema except hived_api
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA hive FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hive TO hive_applications_group;

GRANT EXECUTE ON FUNCTION
      hive.back_from_fork( INT )
    , hive.push_block( hive.blocks, hive.transactions[], hive.transactions_multisig[], hive.operations[], hive.accounts[], hive.account_operations[], hive.applied_hardforks[] )
    , hive.set_irreversible( INT )
    , hive.end_massive_sync( INTEGER )
    , hive.disable_indexes_of_irreversible()
    , hive.enable_indexes_of_irreversible()
    , hive.save_and_drop_indexes_constraints( in _schema TEXT, in _table TEXT )
    , hive.save_and_drop_indexes_foreign_keys( in _table_schema TEXT, in _table_name TEXT )
    , hive.recluster_account_operations_if_index_dropped()
    , hive.restore_indexes( in _table_name TEXT )
    , hive.restore_foreign_keys( in _table_name TEXT )
    , hive.copy_blocks_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_transactions_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_operations_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_signatures_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_accounts_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_account_operations_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_applied_hardforks_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    , hive.remove_unecessary_events( _new_irreversible_block INT )
    , hive.register_table( _table_schema TEXT,  _table_name TEXT, _context_name TEXT ) -- needs to alter tables when indexes are disabled
    , hive.chceck_constrains( _table_schema TEXT,  _table_name TEXT )
    , hive.register_state_provider_tables( _context hive.context_name )
    , hive.app_state_providers_update( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    , hive.app_state_provider_import( _state_provider hive.state_providers, _context hive.context_name )
    , hive.connect( _git_sha TEXT, _block_num hive.blocks.num%TYPE, BOOL )
    , hive.remove_inconsistent_irreversible_data()
    , hive.disable_indexes_of_reversible()
    , hive.enable_indexes_of_reversible()
    , hive.set_irreversible_dirty()
    , hive.set_irreversible_not_dirty()
    , hive.is_irreversible_dirty()
    , hive.disable_fk_of_irreversible()
    , hive.enable_fk_of_irreversible()
    , hive.save_and_drop_constraints( in _table_schema TEXT, in _table_name TEXT )
    , hive.get_block_header( _block_num INT )
    , hive.get_block( _block_num INT, _include_virtual BOOLEAN)
    , hive.get_block_range( _starting_block_num INT, _count INT )
    , hive.get_block_header_json( _block_num INT )
    , hive.get_block_json( _block_num INT, _include_virtual BOOLEAN )
    , hive.get_block_range_json( _starting_block_num INT, _count INT )
    , hive.get_block_from_views( _block_num_start INT, _block_count INT, _include_virtual BOOLEAN)
    , hive.build_block_json(previous BYTEA, "timestamp" TIMESTAMP, witness VARCHAR, transaction_merkle_root BYTEA, extensions jsonb, witness_signature BYTEA, transactions hive.transaction_type[], block_id BYTEA, signing_key TEXT, transaction_ids BYTEA[])
    , hive.transactions_to_json(transactions hive.transaction_type[])

    , hive._operation_bin_in(bytea)
    , hive._operation_bin_in_internal(internal)
    , hive._operation_in(cstring)
    , hive._operation_out(hive.operation)
    , hive._operation_bin_in_internal(internal)
    , hive._operation_bin_in(bytea)
    , hive._operation_bin_out(hive.operation)
    , hive._operation_eq(hive.operation, hive.operation)
    , hive._operation_ne(hive.operation, hive.operation)
    , hive._operation_gt(hive.operation, hive.operation)
    , hive._operation_ge(hive.operation, hive.operation)
    , hive._operation_lt(hive.operation, hive.operation)
    , hive._operation_le(hive.operation, hive.operation)
    , hive._operation_cmp(hive.operation, hive.operation)
    , hive._operation_to_jsonb(hive.operation)
    , hive._operation_from_jsonb(jsonb)
    , hive.operation_to_jsontext(hive.operation)
    , hive.operation_from_jsontext(TEXT)
    , hive.create_database_hash(schema_name TEXT)
    , hive.calculate_schema_hash(schema_name TEXT)
    , hive.are_indexes_dropped()
    , hive.are_fk_dropped()
    , hive.check_owner( _context hive.context_name, _context_owner TEXT )
    , hive.can_impersonate(_role_to_check IN TEXT, _required_role IN TEXT)
    , hive.unreachable_event_id()
    , hive.max_block_num()
    , hive.max_fork_id()
    , hive.initialize_extension_data()
    , hive.ignore_registered_table_edition( pg_ddl_command )
    , hive.get_wal_sequence_number()
    , hive.update_wal_sequence_number(_new_sequence_number INTEGER)
    , hive.update_wal_sequence_number(_new_sequence_number INTEGER)
    , hive.operation_id( _block_num INTEGER, _type INTEGER, _pos INTEGER )
    , hive.operation_id_to_pos( _id hive.operations.id%TYPE )
    , hive.operation_id_to_type_id( _id hive.operations.id%TYPE )
    , hive.operation_id_to_block_num( _id hive.operations.id%TYPE )
    , hive.operation_id_to_pos( _id hive.operations.id%TYPE )
    , hive.operation_id_to_type_id( _id hive.operations.id%TYPE )
    , hive.operation_id_to_block_num( _id hive.operations.id%TYPE )
    , hive.reanalyze_indexes_with_expressions()
TO hived_group;

--- Required permissions to execute all callees of app_check_contexts_synchronized
GRANT EXECUTE ON FUNCTION
      hive.app_context_detach(_contexts hive.contexts_group)
    , hive.app_context_detach( _context hive.context_name )
    , hive.context_detach
    , hive.create_all_irreversible_blocks_view
    , hive.create_all_irreversible_transactions_view
    , hive.create_all_irreversible_operations_view
    , hive.create_all_irreversible_operations_view_extended
    , hive.create_all_irreversible_signatures_view
    , hive.create_all_irreversible_accounts_view
    , hive.create_all_irreversible_account_operations_view
    , hive.create_all_irreversible_applied_hardforks_view
    , hive.context_back_from_fork
    , hive.back_from_fork_one_table
    , hive.remove_obsolete_operations
    , hive.detach_table
    , hive.app_check_contexts_synchronized(_contexts hive.contexts_group)
TO hived_group;

GRANT USAGE ON SCHEMA hive to haf_maintainer;
GRANT EXECUTE ON PROCEDURE hive.proc_perform_dead_app_contexts_auto_detach( IN _app_timeout INTERVAL ) TO haf_maintainer;
GRANT EXECUTE ON FUNCTION hive.is_instance_ready() TO haf_maintainer;
GRANT ALL ON hive.contexts TO haf_maintainer;
GRANT SELECT ON hive.contexts_attachment TO haf_maintainer;
GRANT SELECT ON hive.indexes_constraints TO haf_maintainer;

REVOKE EXECUTE ON FUNCTION
      hive.back_from_fork( INT )
    , hive.push_block( hive.blocks, hive.transactions[], hive.transactions_multisig[], hive.operations[], hive.accounts[], hive.account_operations[], hive.applied_hardforks[] )
    , hive.set_irreversible( INT )
    , hive.end_massive_sync( INTEGER )
    , hive.copy_blocks_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_transactions_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_operations_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_signatures_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_applied_hardforks_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    , hive.remove_unecessary_events( _new_irreversible_block INT )
    , hive.initialize_extension_data()
FROM hive_applications_group;

REVOKE EXECUTE ON PROCEDURE
      hive.proc_perform_dead_app_contexts_auto_detach( IN _app_timeout INTERVAL )
FROM hive_applications_group,
     public;
