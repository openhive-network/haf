#include <hive/plugins/sql_serializer/variant_operation_deserializer.hpp>

namespace hive::plugins::sql_serializer {

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::asset& type )const
  {
    return '(' + std::to_string( type.amount.value ) + ',' + std::to_string( type.symbol.asset_num ) + ')';
  }
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::price& type )const
  {
    return '(' + this->operator()( type.base ) + ',' + this->operator()( type.quote ) + ')';
  }
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const fc::time_point_sec& type )const
  {
    return "to_timestamp(" + std::to_string( type.sec_since_epoch() ) + ')';
  }
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::authority& type )const
  {
    std::string op_str = '(' + type.weight_threshold + ",ARRAY[";

    for( size_t i = 0; i < type.account_auths.size(); ++i )
    {
      if( i )
        op_str += ',';

      op_str += "('" + type.account_auths.nth( i )->first + "'," + std::to_string( type.account_auths.nth( i )->second ) + ')';
    }

    op_str += "]::hive._account_auths_authority[],ARRAY[";

    for( size_t i = 0; i < type.key_auths.size(); ++i )
    {
      if( i )
        op_str += ',';

      op_str += "('" + static_cast<std::string>(type.key_auths.nth( i )->first) + "'," + std::to_string( type.key_auths.nth( i )->second ) + ')';
    }

    return op_str + "])";
  }
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::legacy_chain_properties& type )const
  {
    return "((" + std::to_string( type.account_creation_fee.amount.value ) + ",ROW(" + std::to_string( type.account_creation_fee.symbol.ser ) + ")),"
      + std::to_string( type.maximum_block_size ) + ',' + std::to_string( type.hbd_interest_rate ) + ')';
  }
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const boost::container::flat_set<hp::account_name_type>& type )const
  {
    std::string op_str = "ARRAY[";

    for( auto it = type.begin(); it != type.end(); ++it )
    {
      if( it != type.begin() )
        op_str += ',';

      op_str += '"' + it->operator std::string() + '"';
    }

    return op_str + ']';
  }

  struct signed_block_header_extension_visitor
  {
    using result_type = std::string;

    result_type operator()( const hive::void_t& )const
    {
      return "ROW()::hive.void_t";
    }
    result_type operator()( const hp::version& type )const
    {
      return "ROW(" + std::to_string(type.v_num) + "::hive.version";
    }
    result_type operator()( const hp::hardfork_version_vote& type )const
    {
      return '(' + this->operator()( type.hf_version ) + ",to_timestamp("
        + std::to_string( type.hf_time.sec_since_epoch() ) + "))::hive.hardfork_version_vote";
    }
#ifdef IS_TEST_NET
    struct required_automated_actions_visitor
    {
      using result_type = std::string;
      result_type operator()( const hp::example_required_action& type )const
      {
        return "ROW('" + type.account + "')::hive.example_required_action";
      }
    };
    struct optional_automated_actions_visitor
    {
      using result_type = std::string;
      result_type operator()( const hp::example_optional_action& type )const
      {
        return "ROW('" + type.account + "')::hive.example_optional_action";
      }
    };

    static constexpr required_automated_actions_visitor raav{};
    static constexpr optional_automated_actions_visitor oaav{};

    result_type operator()( const hp::required_automated_actions& type )const
    {
      std::string op_str = "ARRAY[";

      for( auto it = type.begin(); it != type.end(); ++it )
      {
        if( it != type.begin() )
          op_str += ',';

        op_str += '"' + it->visit( raav ) + '"';
      }

      return op_str + "]::hive.required_automated_actions::hive.hive_block_header_extension";
    }
    result_type operator()( const hp::optional_automated_actions& type )const
    {
      std::string op_str = "ARRAY[";

      for( auto it = type.begin(); it != type.end(); ++it )
      {
        if( it != type.begin() )
          op_str += ',';

        op_str += '"' + it->visit( oaav ) + '"';
      }

      return op_str + "]::hive.optional_automated_actions::hive.hive_block_header_extension";
    }
#endif
  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::signed_block_header& type )const
  {
    static constexpr signed_block_header_extension_visitor sb_header_visitor{};

    std::string op_str = '(' + escape_raw( type.previous ) + ',' + this->operator()( type.timestamp ) + ",'"
      + type.witness + "'," + escape_raw( type.transaction_merkle_root ) + ",ARRAY[";

    for( auto it = type.extensions.begin(); it != type.extensions.end(); ++it )
    {
      if( it != type.extensions.begin() )
        op_str += ',';

      op_str += it->visit( sb_header_visitor );
    }

    return op_str + "]::hive.block_header_extensions," + escape_raw( type.witness_signature ) + ')';
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::vote_operation& op )const
  {
    return "('"
      + op.voter + "','" + op.author + "','" + escape( op.permlink ) + "'," + std::to_string( op.weight )
      + ")::hive.vote_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_operation& op )const
  {
    return "('"
      + op.parent_author + "','" + escape( op.parent_permlink ) + "','" + op.author + "','" + op.permlink + "','" + escape( op.title ) + "','"
      + op.body + "','" + op.json_metadata.operator const std::string&()
      + "')::hive.comment_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "'," + this->operator()( op.amount ) + ",'" + escape( op.memo )
      + "')::hive.transfer_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_to_vesting_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "'," + this->operator()( op.amount )
      + ")::hive.transfer_to_vesting_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::withdraw_vesting_operation& op )const
  {
    return "('"
      + op.account + "'," + this->operator()( op.vesting_shares )
      + ")::hive.withdraw_vesting_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::limit_order_create_operation& op )const
  {
    return "('"
      + op.owner + "'," + std::to_string( op.orderid ) + ',' + this->operator()( op.amount_to_sell ) + ','
      + this->operator()( op.min_to_receive ) + ',' + std::to_string( op.fill_or_kill ) + ',' + this->operator()( op.expiration )
      + ")::hive.limit_order_create_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::limit_order_cancel_operation& op )const
  {
    return "('"
      + op.owner + "'," + std::to_string( op.orderid )
      + ")::hive.limit_order_cancel_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::feed_publish_operation& op )const
  {
    return "('"
      + op.publisher + "'," + this->operator()( op.exchange_rate )
      + ")::hive.feed_publish_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::convert_operation& op )const
  {
    return "('"
      + op.owner + "'," + std::to_string( op.requestid ) + ',' + this->operator()( op.amount )
      + ")::hive.convert_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_create_operation& op )const
  {
    return "("
      + this->operator()( op.fee ) + ",'" + op.creator + "','" + op.new_account_name + "'," + this->operator()( op.owner ) + ','
      + this->operator()( op.active ) + ',' + this->operator()( op.posting ) + ",'" + static_cast<std::string>( op.memo_key ) + "','"
      + escape( op.json_metadata.operator const std::string&() )
      + "')::hive.account_create_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_update_operation& op )const
  {
    return "('"
      + op.account + "'," + this->operator()( op.owner ) + ',' + this->operator()( op.active ) + ',' + this->operator()( op.posting )
      + ",'" + static_cast<std::string>( op.memo_key ) + "','" + escape( op.json_metadata.operator const std::string&() )
      + "')::hive.account_update_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::witness_update_operation& op )const
  {
    return "('"
      + op.owner + "','" + escape( op.url ) + "','" + static_cast<std::string>( op.block_signing_key ) + "',"
      + this->operator()( op.props ) + ',' + this->operator()( op.fee )
      + ")::hive.witness_update_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_witness_vote_operation& op )const
  {
    return "('"
      + op.account + "','" + op.account + "'," + std::to_string( op.approve )
      + ")::hive.account_witness_vote_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_witness_proxy_operation& op )const
  {
    return "('"
      + op.account + "','" + op.proxy
      + "')::hive.account_witness_proxy_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::pow_operation& op )const
  {
    return "('"
      + op.worker_account + "'," + escape_raw( op.block_id ) + ',' + std::to_string( op.nonce ) + ",('"
      + static_cast<std::string>(op.work.worker) + "'," + escape_raw( op.work.input ) + ',' + escape_raw( op.work.signature )
      + ',' + escape_raw( op.work.work ) + ")," + this->operator()( op.props )
      + ")::hive.pow_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::custom_operation& op )const
  {
    return "("
      + this->operator()( op.required_auths ) + ',' + std::to_string( op.id ) + ',' + escape_raw( op.data )
      + ")::hive.custom_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::report_over_production_operation& op )const
  {
    return "('"
      + op.reporter + "'," + this->operator()( op.first_block ) + ',' + this->operator()( op.second_block )
      + ")::hive.report_over_production_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::delete_comment_operation& op )const
  {
    return "('"
      + op.author + "','" + escape( op.permlink )
      + "')::hive.delete_comment_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::custom_json_operation& op )const
  {
    return "("
      + this->operator()( op.required_auths ) + ',' + this->operator()( op.required_posting_auths ) + ",'"
      + escape( op.id.operator std::string() ) + "','" + escape( op.json.operator const std::string&() )
      + "')::hive.custom_json_operation";
  }

  struct comment_options_extensions_visitor
  {
    using result_type = std::string;

    result_type operator()( const hp::comment_payout_beneficiaries& type )const
    {
      std::string res_str = "ROW(ARRAY[";

      for( auto it = type.beneficiaries.begin(); it != type.beneficiaries.end(); ++it )
      {
        if( it != type.beneficiaries.begin() )
          res_str += ',';

        res_str += "('" + it->account +"'," + std::to_string( it->weight ) + ')';
      }

      return res_str + "]::hive.beneficiary_route_type[])::hive.comment_payout_beneficiaries";
    }
#ifdef HIVE_ENABLE_SMT
    struct votable_asset_info_visitor
    {
      using result_type = std::string;

      result_type operator()( const hp::votable_asset_info_v1& type )const
      {
        return '(' + std::to_string( type.max_accepted_payout.value ) + ','
          + std::to_string( type.allow_curation_rewards ) + ")::hive.votable_asset_info_v1";
      }
    };

    result_type operator()( const hp::allowed_vote_assets& type )const
    {
      static constexpr votable_asset_info_visitor vaiv;

      std::string res_str = "ROW(ARRAY[";

      for( auto it = type.votable_assets.begin(); it != type.votable_assets.end(); ++it )
      {
        if( it != type.votable_assets.begin() )
          res_str += ',';

        res_str += "(" + std::to_string( it->first.asset_num ) + ',' + it->second.visit( vaiv );
      }

      return res_str + "]::hive.beneficiary_route_type[])::hive.comment_payout_beneficiaries";
    }
#endif

  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_options_operation& op )const
  {
    static constexpr comment_options_extensions_visitor coev{};

    std::string op_str = "('"
      + op.author + "','" + escape( op.permlink ) + "'," + this->operator()( op.max_accepted_payout ) + ','
      + std::to_string( op.percent_hbd ) + ',' + std::to_string( op.allow_votes ) + ','
      + std::to_string( op.allow_curation_rewards ) + ",ARRAY[";

    for( auto it = op.extensions.begin(); it != op.extensions.end(); ++it )
    {
      if( it != op.extensions.begin() )
        op_str += ',';

      op_str += it->visit( coev );
    }

    return op_str + "]::hive.comment_options_extensions_type)::hive.comment_options_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::set_withdraw_vesting_route_operation& op )const
  {
    return "('"
      + op.from_account + "','" + op.to_account + "'," + std::to_string( op.percent ) + ',' + std::to_string( op.auto_vest )
      + ")::hive.set_withdraw_vesting_route_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::limit_order_create2_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.limit_order_create2_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::claim_account_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.claim_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::create_claimed_account_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.create_claimed_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::request_account_recovery_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.request_account_recovery_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::recover_account_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.recover_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::change_recovery_account_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.change_recovery_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::escrow_transfer_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.escrow_transfer_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::escrow_dispute_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.escrow_dispute_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::escrow_release_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.escrow_release_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::pow2_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.pow2_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::escrow_approve_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.escrow_approve_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_to_savings_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.transfer_to_savings_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_from_savings_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.transfer_from_savings_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::cancel_transfer_from_savings_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.cancel_transfer_from_savings_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::custom_binary_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.custom_binary_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::decline_voting_rights_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.decline_voting_rights_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::reset_account_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.reset_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::set_reset_account_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.set_reset_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::claim_reward_balance_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.claim_reward_balance_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::delegate_vesting_shares_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.delegate_vesting_shares_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_create_with_delegation_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.account_create_with_delegation_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::witness_set_properties_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.witness_set_properties_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_update2_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.account_update2_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::create_proposal_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.create_proposal_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::update_proposal_votes_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.update_proposal_votes_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::remove_proposal_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.remove_proposal_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::update_proposal_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.update_proposal_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::collateralized_convert_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.collateralized_convert_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::recurrent_transfer_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.recurrent_transfer_operation";
  }


  /// SMT operations
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::claim_reward_balance2_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.claim_reward_balance2_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_setup_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.smt_setup_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_setup_emissions_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.smt_setup_emissions_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_set_setup_parameters_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.smt_set_setup_parameters_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_set_runtime_parameters_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.smt_set_runtime_parameters_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_create_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.smt_create_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_contribute_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.smt_contribute_operation";
  }


  /// virtual operations below this point
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_convert_request_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.fill_convert_request_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::author_reward_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.author_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::curation_reward_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.curation_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_reward_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.comment_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::liquidity_reward_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.liquidity_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::interest_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.interest_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_vesting_withdraw_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.fill_vesting_withdraw_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_order_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.fill_order_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::shutdown_witness_operation& op )const
  {
    return "ROW("
      + std::string{}
      + ")::hive.shutdown_witness_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_transfer_from_savings_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.fill_transfer_from_savings_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::hardfork_operation& op )const
  {
    return "ROW("
      + std::string{}
      + ")::hive.hardfork_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_payout_update_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.comment_payout_update_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::return_vesting_delegation_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.return_vesting_delegation_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_benefactor_reward_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.comment_benefactor_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::producer_reward_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.producer_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::clear_null_account_balance_operation& op )const
  {
    return "ROW("
      + std::string{}
      + ")::hive.clear_null_account_balance_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::proposal_pay_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.proposal_pay_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::sps_fund_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.sps_fund_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::hardfork_hive_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.hardfork_hive_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::hardfork_hive_restore_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.hardfork_hive_restore_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::delayed_voting_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.delayed_voting_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::consolidate_treasury_balance_operation& op )const
  {
    return "ROW("
      + std::string{}
      + ")::hive.consolidate_treasury_balance_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::effective_comment_vote_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.effective_comment_vote_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::ineffective_delete_comment_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.ineffective_delete_comment_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::sps_convert_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.sps_convert_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::expired_account_notification_operation& op )const
  {
    return "ROW("
      + std::string{}
      + ")::hive.expired_account_notification_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::changed_recovery_account_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.changed_recovery_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_to_vesting_completed_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.transfer_to_vesting_completed_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::pow_reward_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.pow_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::vesting_shares_split_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.vesting_shares_split_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_created_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.account_created_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_collateralized_convert_request_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.fill_collateralized_convert_request_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::system_warning_operation& op )const
  {
    return "ROW("
      + std::string{}
      + ")::hive.system_warning_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_recurrent_transfer_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.fill_recurrent_transfer_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::failed_recurrent_transfer_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.failed_recurrent_transfer_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::limit_order_cancelled_operation& op )const
  {
    return "("
      + std::string{}
      + ")::hive.limit_order_cancelled_operation";
  }

}
