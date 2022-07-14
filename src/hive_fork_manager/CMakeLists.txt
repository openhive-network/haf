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

            # Operation Types
            operations/types/domains.sql
            operations/types/asset.sql
            operations/types/authority.sql
            operations/types/legacy_chain_properties.sql
            operations/types/pow.sql
            operations/types/block_header.sql
            operations/types/comment_options_extension.sql
            operations/types/extensions.sql
            operations/types/pow2.sql
            operations/types/update_proposal_extension.sql
            operations/types/smt_generation_policy.sql
            operations/types/smt_emissions_unit.sql
            operations/types/smt_setup_parameter.sql
            operations/types/curve_id.sql
            operations/types/smt_runtime_parameter.sql

            # Hive operations
            operations/hive/vote_operation.sql
            operations/hive/comment_operation.sql
            operations/hive/transfer_operation.sql
            operations/hive/transfer_to_vesting_operation.sql
            operations/hive/withdraw_vesting_operation.sql
            operations/hive/limit_order_create_operation.sql
            operations/hive/limit_order_cancel_operation.sql
            operations/hive/feed_publish_operation.sql
            operations/hive/convert_operation.sql
            operations/hive/account_create_operation.sql
            operations/hive/account_update_operation.sql
            operations/hive/witness_update_operation.sql
            operations/hive/account_witness_vote_operation.sql
            operations/hive/account_witness_proxy_operation.sql
            operations/hive/pow_operation.sql
            operations/hive/custom_operation.sql
            operations/hive/report_over_production_operation.sql
            operations/hive/delete_comment_operation.sql
            operations/hive/custom_json_operation.sql
            operations/hive/comment_options_operation.sql
            operations/hive/set_withdraw_vesting_route_operation.sql
            operations/hive/limit_order_create2_operation.sql
            operations/hive/claim_account_operation.sql
            operations/hive/create_claimed_account_operation.sql
            operations/hive/request_account_recovery_operation.sql
            operations/hive/recover_account_operation.sql
            operations/hive/change_recovery_account_operation.sql
            operations/hive/escrow_transfer_operation.sql
            operations/hive/escrow_dispute_operation.sql
            operations/hive/escrow_release_operation.sql
            operations/hive/pow2_operation.sql
            operations/hive/escrow_approve_operation.sql
            operations/hive/transfer_to_savings_operation.sql
            operations/hive/transfer_from_savings_operation.sql
            operations/hive/cancel_transfer_from_savings_operation.sql
            operations/hive/custom_binary_operation.sql
            operations/hive/decline_voting_rights_operation.sql
            operations/hive/reset_account_operation.sql
            operations/hive/set_reset_account_operation.sql
            operations/hive/claim_reward_balance_operation.sql
            operations/hive/delegate_vesting_shares_operation.sql
            operations/hive/account_create_with_delegation_operation.sql
            operations/hive/witness_set_properties_operation.sql
            operations/hive/account_update2_operation.sql
            operations/hive/collateralized_convert_operation.sql
            operations/hive/recurrent_transfer_operation.sql
            operations/hive/claim_reward_balance2_operation.sql

            # SPS operations
            operations/sps/create_proposal_operation.sql
            operations/sps/update_proposal_votes_operation.sql
            operations/sps/remove_proposal_operation.sql
            operations/sps/update_proposal_operation.sql
            operations/sps/proposal_pay_operation.sql

            # SMT operations
            operations/smt/smt_setup_operation.sql
            operations/smt/smt_setup_emissions_operation.sql
            operations/smt/smt_set_setup_parameters_operation.sql
            operations/smt/smt_set_runtime_parameters_operation.sql
            operations/smt/smt_create_operation.sql
            operations/smt/smt_contribute_operation.sql

            # Virtual operations
            operations/virtual/fill_convert_request_operation.sql
            operations/virtual/author_reward_operation.sql
            operations/virtual/curation_reward_operation.sql
            operations/virtual/comment_reward_operation.sql
            operations/virtual/liquidity_reward_operation.sql
            operations/virtual/interest_operation.sql
            operations/virtual/fill_vesting_withdraw_operation.sql
            operations/virtual/fill_order_operation.sql
            operations/virtual/shutdown_witness_operation.sql
            operations/virtual/fill_transfer_from_savings_operation.sql
            operations/virtual/hardfork_operation.sql
            operations/virtual/comment_payout_update_operation.sql
            operations/virtual/return_vesting_delegation_operation.sql
            operations/virtual/comment_benefactor_reward_operation.sql
            operations/virtual/producer_reward_operation.sql
            operations/virtual/clear_null_account_balance_operation.sql
            operations/virtual/sps_fund_operation.sql
            operations/virtual/hardfork_hive_operation.sql
            operations/virtual/hardfork_hive_restore_operation.sql
            operations/virtual/delayed_voting_operation.sql
            operations/virtual/consolidate_treasury_balance_operation.sql
            operations/virtual/effective_comment_vote_operation.sql
            operations/virtual/ineffective_delete_comment_operation.sql
            operations/virtual/sps_convert_operation.sql
            operations/virtual/expired_account_notification_operation.sql
            operations/virtual/changed_recovery_account_operation.sql
            operations/virtual/transfer_to_vesting_completed_operation.sql
            operations/virtual/pow_reward_operation.sql
            operations/virtual/vesting_shares_split_operation.sql
            operations/virtual/account_created_operation.sql
            operations/virtual/fill_collateralized_convert_request_operation.sql
            operations/virtual/system_warning_operation.sql
            operations/virtual/fill_recurrent_transfer_operation.sql
            operations/virtual/failed_recurrent_transfer_operation.sql
            operations/virtual/limit_order_cancelled_operation.sql

            # Operations variant
            operations/types/hive_operation.sql

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
