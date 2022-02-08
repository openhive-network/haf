ADD_PSQL_EXTENSION(
    NAME hive_fork_manager
    SOURCES context_rewind/data_schema.sql
            context_rewind/names.sql
            context_rewind/triggers.sql
            context_rewind/event_triggers.sql
            context_rewind/register_table.sql
            context_rewind/detach_table.sql
            context_rewind/back_from_fork.sql
            context_rewind/irreversible.sql
            context_rewind/rewind_api.sql
            tools.sql
            events_queue.sql
            forks.sql
            app_context.sql
            irreversible_blocks.sql
            reversible_blocks.sql
            block_views_for_head_block.sql
            blocks_views_for_contexts.sql
            block_day_stats_view.sql
            block_day_stats_all_op_view.sql
            state_provider.sql
            state_providers/accounts.sql
            hived_connections.sql
            hived_api_impl.sql
            app_api_impl.sql
            hived_api.sql
            app_api.sql
            authorization.sql
            get_impacted_accounts.sql
            get_impacted_balances.sql
            get_legacy_style_operation.sql
)

ADD_SUBDIRECTORY( shared_lib )

ADD_DEPENDENCIES( extension.${EXTENSION_NAME} hfm-${GIT_REVISION} )
