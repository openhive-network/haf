#pragma once

#include <hive/plugins/sql_serializer/data_2_sql_tuple_base.h>

#include <hive/protocol/operations.hpp>

namespace hive::plugins::sql_serializer {

  namespace hp = hive::protocol;

  class variant_operation_deserializer : public data2_sql_tuple_base
  {
  public:
    using data2_sql_tuple_base::data2_sql_tuple_base;

    using result_type = std::string;

    result_type operator()( const hp::vote_operation& op )const;
    result_type operator()( const hp::comment_operation& op )const;
    result_type operator()( const hp::transfer_operation& op )const;
    result_type operator()( const hp::transfer_to_vesting_operation& op )const;
    result_type operator()( const hp::withdraw_vesting_operation& op )const;
    result_type operator()( const hp::limit_order_create_operation& op )const;
    result_type operator()( const hp::limit_order_cancel_operation& op )const;
    result_type operator()( const hp::feed_publish_operation& op )const;
    result_type operator()( const hp::convert_operation& op )const;
    result_type operator()( const hp::account_create_operation& op )const;
    result_type operator()( const hp::account_update_operation& op )const;
    result_type operator()( const hp::witness_update_operation& op )const;
    result_type operator()( const hp::account_witness_vote_operation& op )const;
    result_type operator()( const hp::account_witness_proxy_operation& op )const;
    result_type operator()( const hp::pow_operation& op )const;
    result_type operator()( const hp::custom_operation& op )const;
    result_type operator()( const hp::report_over_production_operation& op )const;
    result_type operator()( const hp::delete_comment_operation& op )const;
    result_type operator()( const hp::custom_json_operation& op )const;
    result_type operator()( const hp::comment_options_operation& op )const;
    result_type operator()( const hp::set_withdraw_vesting_route_operation& op )const;
    result_type operator()( const hp::limit_order_create2_operation& op )const;
    result_type operator()( const hp::claim_account_operation& op )const;
    result_type operator()( const hp::create_claimed_account_operation& op )const;
    result_type operator()( const hp::request_account_recovery_operation& op )const;
    result_type operator()( const hp::recover_account_operation& op )const;
    result_type operator()( const hp::change_recovery_account_operation& op )const;
    result_type operator()( const hp::escrow_transfer_operation& op )const;
    result_type operator()( const hp::escrow_dispute_operation& op )const;
    result_type operator()( const hp::escrow_release_operation& op )const;
    result_type operator()( const hp::pow2_operation& op )const;
    result_type operator()( const hp::escrow_approve_operation& op )const;
    result_type operator()( const hp::transfer_to_savings_operation& op )const;
    result_type operator()( const hp::transfer_from_savings_operation& op )const;
    result_type operator()( const hp::cancel_transfer_from_savings_operation& op )const;
    result_type operator()( const hp::custom_binary_operation& op )const;
    result_type operator()( const hp::decline_voting_rights_operation& op )const;
    result_type operator()( const hp::reset_account_operation& op )const;
    result_type operator()( const hp::set_reset_account_operation& op )const;
    result_type operator()( const hp::claim_reward_balance_operation& op )const;
    result_type operator()( const hp::delegate_vesting_shares_operation& op )const;
    result_type operator()( const hp::account_create_with_delegation_operation& op )const;
    result_type operator()( const hp::witness_set_properties_operation& op )const;
    result_type operator()( const hp::account_update2_operation& op )const;
    result_type operator()( const hp::create_proposal_operation& op )const;
    result_type operator()( const hp::update_proposal_votes_operation& op )const;
    result_type operator()( const hp::remove_proposal_operation& op )const;
    result_type operator()( const hp::update_proposal_operation& op )const;
    result_type operator()( const hp::collateralized_convert_operation& op )const;
    result_type operator()( const hp::recurrent_transfer_operation& op )const;

    /// SMT operations
    result_type operator()( const hp::claim_reward_balance2_operation& op )const;
    result_type operator()( const hp::smt_setup_operation& op )const;
    result_type operator()( const hp::smt_setup_emissions_operation& op )const;
    result_type operator()( const hp::smt_set_setup_parameters_operation& op )const;
    result_type operator()( const hp::smt_set_runtime_parameters_operation& op )const;
    result_type operator()( const hp::smt_create_operation& op )const;
    result_type operator()( const hp::smt_contribute_operation& op )const;

    /// virtual operations below this point
    result_type operator()( const hp::fill_convert_request_operation& op )const;
    result_type operator()( const hp::author_reward_operation& op )const;
    result_type operator()( const hp::curation_reward_operation& op )const;
    result_type operator()( const hp::comment_reward_operation& op )const;
    result_type operator()( const hp::liquidity_reward_operation& op )const;
    result_type operator()( const hp::interest_operation& op )const;
    result_type operator()( const hp::fill_vesting_withdraw_operation& op )const;
    result_type operator()( const hp::fill_order_operation& op )const;
    result_type operator()( const hp::shutdown_witness_operation& op )const;
    result_type operator()( const hp::fill_transfer_from_savings_operation& op )const;
    result_type operator()( const hp::hardfork_operation& op )const;
    result_type operator()( const hp::comment_payout_update_operation& op )const;
    result_type operator()( const hp::return_vesting_delegation_operation& op )const;
    result_type operator()( const hp::comment_benefactor_reward_operation& op )const;
    result_type operator()( const hp::producer_reward_operation& op )const;
    result_type operator()( const hp::clear_null_account_balance_operation& op )const;
    result_type operator()( const hp::proposal_pay_operation& op )const;
    result_type operator()( const hp::sps_fund_operation& op )const;
    result_type operator()( const hp::hardfork_hive_operation& op )const;
    result_type operator()( const hp::hardfork_hive_restore_operation& op )const;
    result_type operator()( const hp::delayed_voting_operation& op )const;
    result_type operator()( const hp::consolidate_treasury_balance_operation& op )const;
    result_type operator()( const hp::effective_comment_vote_operation& op )const;
    result_type operator()( const hp::ineffective_delete_comment_operation& op )const;
    result_type operator()( const hp::sps_convert_operation& op )const;
    result_type operator()( const hp::expired_account_notification_operation& op )const;
    result_type operator()( const hp::changed_recovery_account_operation& op )const;
    result_type operator()( const hp::transfer_to_vesting_completed_operation& op )const;
    result_type operator()( const hp::pow_reward_operation& op )const;
    result_type operator()( const hp::vesting_shares_split_operation& op )const;
    result_type operator()( const hp::account_created_operation& op )const;
    result_type operator()( const hp::fill_collateralized_convert_request_operation& op )const;
    result_type operator()( const hp::system_warning_operation& op )const;
    result_type operator()( const hp::fill_recurrent_transfer_operation& op )const;
    result_type operator()( const hp::failed_recurrent_transfer_operation& op )const;
    result_type operator()( const hp::limit_order_cancelled_operation& op )const;

  private:
    result_type operator()( const hp::asset& type )const;
    result_type operator()( const hp::price& type )const;
    result_type operator()( const fc::time_point_sec& type )const;
    result_type operator()( const hp::authority& type )const;
    result_type operator()( const hp::legacy_chain_properties& type )const;
    result_type operator()( const boost::container::flat_set<hp::account_name_type>& type )const;
    result_type operator()( const hp::signed_block_header& type )const;

    template< typename T >
    result_type operator()( const fc::optional< T >& type )const
    {
      if( type.valid() )
        return this->operator()( type.value() );

      return "NULL";
    }
  };
}
