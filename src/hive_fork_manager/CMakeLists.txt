ADD_PSQL_EXTENSION(
    NAME hive_fork_manager
    SCHEMA_SOURCES schemas.sql
             context_rewind/data_schema_types.sql
             application_loop/stages.sql
             context_rewind/data_schema.sql
             events_queue.sql
             forks.sql
             app_context.sql
             types/operation/operation.sql
             types/operation/operation_flow.sql
             types/operation/operation_impl.sql
             types/operation/operation_cmp.sql
             types/operation/operation_casts.sql
             types/operation/operation_id.sql
             irreversible_blocks.sql
             reversible_blocks.sql
             state_provider.sql
             hived_connections.sql
             hived_api_impl_indexes.sql
             hived_api.sql
             state_providers/keyauth_types.sql
             save_restore_view_data.sql
             application_loop/contexts_log.sql

    DEPLOY_SOURCES trigger_switch/trigger_off.sql
            context_rewind/sink_id_functions.sql
            context_rewind/names.sql
            context_rewind/triggers.sql
            context_rewind/event_triggers.sql
            context_rewind/register_table.sql
            context_rewind/detach_table.sql
            context_rewind/back_from_fork.sql
            context_rewind/irreversible.sql
            context_rewind/rewind_api.sql
            # This file must be also specified here, as it contains functions which definitions should be always overwritten.
            types/operation/compatibility_with_old_haf_apps.sql
            types/operation/operation_flow.sql
            types/operation/operation_id.sql
            tools.sql
            block_views_for_head_block.sql
            block_day_stats_view.sql
            block_day_stats_all_op_view.sql
            blocks_views_for_contexts.sql
            state_providers/keyauth.sql
            get_keyauths.sql
            get_metadata.sql
            get_vesting_balance.sql
            state_providers/accounts.sql
            state_providers/metadata.sql
            hived_api_impl.sql
            app_api_impl.sql
            hived_api.sql
            app_api.sql
            api_helpers/block_api_support.sql
            authorization.sql
            get_impacted_accounts.sql
            get_impacted_balances.sql
            convert_blocks.sql
            get_legacy_style_operation.sql
            extract_set_witness_properties.sql
            trigger_switch/trigger_on.sql

            types/types.sql # drop and recreate operation types on upgrade
            types/cast_functions.sql
            types/casts.sql
            types/operation/operation_flow.sql
            types/process_operation.sql

            application_loop/stages_functions.sql
            application_loop/loop.sql
            application_loop/contexts_log_api.sql

            state_providers/update_providers.sql
)

ADD_SUBDIRECTORY( shared_lib )

ADD_DEPENDENCIES( extension.${EXTENSION_NAME} hfm-${HAF_GIT_REVISION_SHA} )
ADD_DEPENDENCIES( extension.${EXTENSION_NAME} query_supervisor )

MESSAGE(STATUS "Detected root project git revision: ${HAF_GIT_REVISION_SHA}")

