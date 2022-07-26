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
    std::string op_str = '(' + std::to_string( type.weight_threshold ) + ",ARRAY[";

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

      op_str += "('" + this->operator()(type.key_auths.nth( i )->first) + "'," + std::to_string( type.key_auths.nth( i )->second ) + ')';
    }

    return op_str + "]::hive._key_auths_authority[])";
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

      op_str += '\'' + it->operator std::string() + '\'';
    }

    return op_str + ']::hive.account_name_type';
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

  struct future_extensions_visitor
  {
    using result_type = std::string;

    result_type operator()( hive::void_t )const
    {
      return "ROW()::void_t";
    }
  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::extensions_type& type )const
  {
    static constexpr future_extensions_visitor fev{};

    std::string type_str = "ARRAY[";

    for( auto it = type.begin(); it != type.end(); ++it )
    {
      if( it != type.begin() )
        type_str += ',';

      type_str += it->visit( fev );
    }

    return type_str + ']::hive.extensions_type';
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::public_key_type& type )const
  {
    return static_cast< std::string >( type );
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const fc::optional< hp::authority >& type )const
  {
    if( type.valid() )
      return this->operator()( type.value() );

    return "NULL";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const fc::optional< hp::public_key_type >& type )const
  {
    if( type.valid() )
      return this->operator()( type.value() );

    return "NULL";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const flat_set_ex<int64_t>& type )const
  {
    std::string type_str = "ARRAY[";

    for( auto it = type.begin(); it != type.end(); ++it )
    {
      if( it != type.begin() )
        type_str += ',';

      type_str += std::to_string( *it );
    }

    return type_str + ']::NUMERIC[]';
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::vote_operation& op )const
  {
    return "('"
      + op.voter + "','" + op.author + "'," + escape( op.permlink ) + ',' + std::to_string( op.weight )
      + ")::hive.vote_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_operation& op )const
  {
    return "('"
      + op.parent_author + "'," + escape( op.parent_permlink ) + ",'" + op.author + "','" + op.permlink + "'," + escape( op.title ) + ","
      + escape( op.body ) + ',' + escape( op.json_metadata.operator const std::string&() )
      + ")::hive.comment_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "'," + this->operator()( op.amount ) + ',' + escape( op.memo )
      + ")::hive.transfer_operation";
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
    return '('
      + this->operator()( op.fee ) + ",'" + op.creator + "','" + op.new_account_name + "'," + this->operator()( op.owner ) + ','
      + this->operator()( op.active ) + ',' + this->operator()( op.posting ) + ",'" + this->operator()( op.memo_key ) + "',"
      + escape( op.json_metadata.operator const std::string&() )
      + ")::hive.account_create_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_update_operation& op )const
  {
    return "('"
      + op.account + "'," + this->operator()( op.owner ) + ',' + this->operator()( op.active ) + ',' + this->operator()( op.posting )
      + ",'" + this->operator()( op.memo_key ) + "'," + escape( op.json_metadata.operator const std::string&() )
      + ")::hive.account_update_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::witness_update_operation& op )const
  {
    return "('"
      + op.owner + "'," + escape( op.url ) + ",'" + this->operator()( op.block_signing_key ) + "',"
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
      + this->operator()(op.work.worker) + "'," + escape_raw( op.work.input ) + ',' + escape_raw( op.work.signature )
      + ',' + escape_raw( op.work.work ) + ")," + this->operator()( op.props )
      + ")::hive.pow_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::custom_operation& op )const
  {
    return '('
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
      + op.author + "'," + escape( op.permlink )
      + ")::hive.delete_comment_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::custom_json_operation& op )const
  {
    return '('
      + this->operator()( op.required_auths ) + ',' + this->operator()( op.required_posting_auths ) + ','
      + escape( op.id.operator std::string() ) + ',' + escape( op.json.operator const std::string&() )
      + ")::hive.custom_json_operation";
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

        res_str += '(' + std::to_string( it->first.asset_num ) + ',' + it->second.visit( vaiv ) + ')';
      }

      return res_str + "]::hive.beneficiary_route_type[])::hive.comment_payout_beneficiaries";
    }
#endif

  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_options_operation& op )const
  {
    static constexpr comment_options_extensions_visitor coev{};

    std::string op_str = "('"
      + op.author + "'," + escape( op.permlink ) + ',' + this->operator()( op.max_accepted_payout ) + ','
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
    return "('"
      + op.owner + "'," + std::to_string( op.orderid ) + ',' + this->operator()( op.amount_to_sell ) + ','
      + std::to_string( op.fill_or_kill ) + ',' + this->operator()( op.exchange_rate ) + ',' + this->operator()( op.expiration )
      + ")::hive.limit_order_create2_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::claim_account_operation& op )const
  {
    return "('"
      + op.creator + "'," + this->operator()( op.fee ) + ',' + this->operator()( op.extensions )
      + ")::hive.claim_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::create_claimed_account_operation& op )const
  {
    return "('"
      + op.creator + "','" + op.new_account_name + "'," + this->operator()( op.owner ) + ',' + this->operator()( op.active ) + ','
      + this->operator()( op.posting ) + ",'" + this->operator()( op.memo_key ) + "',"
      + escape( op.json_metadata.operator const std::string &() ) + ',' + this->operator()( op.extensions )
      + ")::hive.create_claimed_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::request_account_recovery_operation& op )const
  {
    return "('"
      + op.recovery_account + "','" + op.account_to_recover + "'," + this->operator()( op.new_owner_authority )
      + ',' + this->operator()( op.extensions )
      + ")::hive.request_account_recovery_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::recover_account_operation& op )const
  {
    return '('
      + op.account_to_recover.operator std::string() + "'," + this->operator()( op.new_owner_authority ) + ',' + this->operator()( op.recent_owner_authority )
      + ',' + this->operator()( op.extensions )
      + ")::hive.recover_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::change_recovery_account_operation& op )const
  {
    return "('"
      + op.account_to_recover + "','" + op.new_recovery_account + "'," + this->operator()( op.extensions )
      + ")::hive.change_recovery_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::escrow_transfer_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "','" + op.agent + "'," + std::to_string( op.escrow_id ) + ',' + this->operator()( op.hbd_amount ) + ','
      + this->operator()( op.hive_amount ) + ',' + this->operator()( op.fee ) + ',' + this->operator()( op.ratification_deadline ) + ','
      + this->operator()( op.escrow_expiration ) + ',' + escape( op.json_meta.operator const std::string&() )
      + ")::hive.escrow_transfer_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::escrow_dispute_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "','" + op.agent + "','" + op.who + "'," + std::to_string( op.escrow_id )
      + ")::hive.escrow_dispute_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::escrow_release_operation& op )const
  {
    return '('
      + op.from.operator std::string() + "','" + op.to + "','" + op.agent + "','" + op.who + "','" + op.receiver + "'," + std::to_string( op.escrow_id ) + ','
      + this->operator()( op.hbd_amount ) + ',' + this->operator()( op.hive_amount )
      + ")::hive.escrow_release_operation";
  }

  struct pow2_work_visitor : public data2_sql_tuple_base
  {
    using result_type = std::string;

    result_type operator()( const hp::pow2_input& type )const
    {
      return "('" + type.worker_account + "'," + escape_raw( type.prev_block ) + ',' + std::to_string( type.nonce ) + ')';
    }

    result_type operator()( const fc::equihash::proof& type )const
    {
      std::string res_str = '(' + std::to_string( type.n ) + ',' + std::to_string( type.k ) + ",'" + escape_raw( type.seed ) + ",ARRAY[";

      for( auto it = type.inputs.begin(); it != type.inputs.end(); ++it )
      {
        if( it != type.inputs.begin() )
          res_str += ',';

        res_str += std::to_string( *it );
      }

      return res_str + "]::int8[])";
    }

    result_type operator()( const hp::pow2& type )const
    {
      return '(' + this->operator()( type.input ) + ',' + std::to_string( type.pow_summary ) + ")::hive.pow2";
    }

    result_type operator()( const hp::equihash_pow& type )const
    {
      return '(' + this->operator()( type.input ) + ',' + this->operator()( type.proof ) + ','
      + escape_raw( type.prev_block ) + ',' + std::to_string( type.pow_summary ) + ")::hive.equihash_pow";
    }
  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::pow2_operation& op )const
  {
    static constexpr pow2_work_visitor pwv{};

    return '(' + op.work.visit( pwv ) + ',' + this->operator()( op.new_owner_key ) + ','
      + this->operator()( op.props ) + ")::hive.pow2_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::escrow_approve_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "','" + op.agent + "','" + op.who + "'," + std::to_string( op.escrow_id ) + ',' + std::to_string( op.approve )
      + ")::hive.escrow_approve_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_to_savings_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "'," + this->operator()( op.amount ) + ',' + escape( op.memo )
      + ")::hive.transfer_to_savings_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_from_savings_operation& op )const
  {
    return "('"
      + op.from + "'," + std::to_string( op.request_id ) + ",'" + op.to + ',' + this->operator()( op.amount ) + ',' + escape( op.memo )
      + ")::hive.transfer_from_savings_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::cancel_transfer_from_savings_operation& op )const
  {
    return "('"
      + op.from + "'," + std::to_string( op.request_id )
      + ")::hive.cancel_transfer_from_savings_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::custom_binary_operation& op )const
  {
    std::string str_op = '(' + this->operator()( op.required_owner_auths ) + ',' + this->operator()( op.required_active_auths ) + ','
      + this->operator()( op.required_posting_auths ) + ",ARRAY[";

    for( auto it = op.required_auths.begin(); it != op.required_auths.end(); ++it )
    {
      if( it != op.required_auths.begin() )
        str_op += ',';

      str_op += this->operator()( *it );
    }

    return str_op + "]::hive.authority[]," + escape( op.id.operator std::string() ) + ',' + escape_raw( op.data ) + ")::hive.custom_binary_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::decline_voting_rights_operation& op )const
  {
    return "('"
      + op.account + "'," + std::to_string( op.decline )
      + ")::hive.decline_voting_rights_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::reset_account_operation& op )const
  {
    return "('"
      + op.reset_account + "','" + op.account_to_reset + "'," + this->operator()( op.new_owner_authority )
      + ")::hive.reset_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::set_reset_account_operation& op )const
  {
    return "('"
      + op.account + "','" + op.current_reset_account + "','" + op.reset_account
      + "')::hive.set_reset_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::claim_reward_balance_operation& op )const
  {
    return "('"
      + op.account + "'," + this->operator()( op.reward_hive ) + ',' + this->operator()( op.reward_hbd ) + ','
      + this->operator()( op.reward_vests )
      + ")::hive.claim_reward_balance_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::delegate_vesting_shares_operation& op )const
  {
    return "('"
      + op.delegator + "','" + op.delegatee + "'," + this->operator()( op.vesting_shares )
      + ")::hive.delegate_vesting_shares_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_create_with_delegation_operation& op )const
  {
    return '('
      + this->operator()( op.fee ) + ',' + this->operator()( op.delegation ) + ",'" + op.creator + "','" + op.new_account_name + "',"
      + this->operator()( op.owner ) + ',' + this->operator()( op.active ) + ',' + this->operator()( op.posting ) + ','
      + this->operator()( op.memo_key ) + ',' + escape( op.json_metadata.operator const std::string&() ) + ',' + this->operator()( op.extensions )
      + ")::hive.account_create_with_delegation_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::witness_set_properties_operation& op )const
  {
    std::string str_op = "('" + op.owner + "',ARRAY[";

    for( auto it = op.props.begin(); it != op.props.end(); ++it )
    {
      if( it != op.props.begin() )
        str_op += ',';

      str_op += "('" + it->first + "'," + escape_raw( it->second ) + ')';
    }

    return "]::hive._props_witness_set_properties_operation[]," + this->operator()( op.extensions ) + ")::hive.witness_set_properties_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_update2_operation& op )const
  {
    return "('"
      + op.account + "'," + this->operator()( op.owner ) + ',' + this->operator()( op.active ) + ','
      + this->operator()( op.posting ) + ',' + this->operator()( op.memo_key ) + ',' + escape( op.json_metadata.operator const std::string&() )
      + ',' + escape( op.posting_json_metadata.operator const std::string&() ) + ',' + this->operator()( op.extensions )
      + ")::hive.account_update2_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::create_proposal_operation& op )const
  {
    return "('"
      + op.creator + "','" + op.receiver + "'," + this->operator()( op.start_date ) + ',' + this->operator()( op.end_date ) + ','
      + this->operator()( op.daily_pay ) + ',' + escape( op.subject ) + ',' + escape( op.permlink ) + ',' + this->operator()( op.extensions )
      + ")::hive.create_proposal_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::update_proposal_votes_operation& op )const
  {
    return "('"
      + op.voter + "'," + this->operator()( op.proposal_ids ) + ',' + std::to_string( op.approve ) + ',' + this->operator()( op.extensions )
      + ")::hive.update_proposal_votes_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::remove_proposal_operation& op )const
  {
    return "('"
      + op.proposal_owner + "'," + this->operator()( op.proposal_ids ) + ',' + this->operator()( op.extensions )
      + ")::hive.remove_proposal_operation";
  }

  struct update_proposal_extensions_visitor
  {
    using result_type = std::string;

    result_type operator()( const hive::void_t& )const
    {
      return "ROW()::hive.void_t";
    }

    result_type operator()( const hp::update_proposal_end_date& type )const
    {
      return "ROW(to_timestamp(" + std::to_string( type.end_date.sec_since_epoch() ) + "))::hive.update_proposal_end_date";
    }
  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::update_proposal_operation& op )const
  {
    static constexpr update_proposal_extensions_visitor upev{};

    std::string str_op = '('
      + std::to_string( op.proposal_id ) + ",'" + op.creator + "'," + this->operator()( op.daily_pay ) + ',' + escape( op.subject ) + ','
      + escape( op.permlink ) + ",ARRAY[";

    for( auto it = op.extensions.begin(); it != op.extensions.end(); ++it )
    {
      if( it != op.extensions.begin() )
        str_op += ',';

      str_op += it->visit( upev );
    }

    return str_op + "]::hive.update_proposal_extensions_type)::hive.update_proposal_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::collateralized_convert_operation& op )const
  {
    return "('"
      + op.owner + "'," + std::to_string( op.requestid ) + ',' + this->operator()( op.amount )
      + ")::hive.collateralized_convert_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::recurrent_transfer_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "'," + this->operator()( op.amount ) + ',' + escape( op.memo ) + ',' + std::to_string( op.recurrence ) + ','
      + std::to_string( op.executions ) + ',' + this->operator()( op.extensions )
      + ")::hive.recurrent_transfer_operation";
  }

#ifdef HIVE_ENABLE_SMT

  /// SMT operations
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::claim_reward_balance2_operation& op )const
  {
    std::string str_op = "('" + op.account + "'," + this->operator()( op.extensions ) + ",ARRAY[";

    for( auto it = op.reward_tokens.begin(); it != op.reward_tokens.end(); ++it )
    {
      if( it != op.reward_tokens.begin() )
        str_op += ',';

      str_op += this->operator()( *it );
    }

    return str_op + "]::hive.asset[])::hive.claim_reward_balance2_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()(
    const boost::container::flat_map< hp::account_name_type, uint16_t >& map )const
  {
    std::string str_map = "ARRAY[";
    for( auto it = map.begin(); it != map.end(); ++it )
    {
      if( it != map.begin() )
        str_map += ',';

      str_map += "('" + it->first + "'," + std::to_string( it->second ) + ')';
    }
    return str_map + "]::hive._unit_smt_generation_unit[]";
  };

  class variant_operation_deserializer::smt_generation_policy_visitor
  {
  public:
    using result_type = std::string;

    const variant_operation_deserializer& vod;

    constexpr smt_generation_policy_visitor( const variant_operation_deserializer& vod )
      : vod( vod ) {}

    result_type operator()( const hp::smt_generation_unit& type )const
    {
      return '(' + vod( type.hive_unit ) + ',' + vod( type.token_unit ) + ')';
    }

    result_type operator()( const hp::smt_capped_generation_policy& type )const
    {
      return '(' + this->operator()( type.pre_soft_cap_unit ) + ',' + this->operator()( type.post_soft_cap_unit ) + ','
        + std::to_string( type.soft_cap_percent ) + ',' + std::to_string( type.min_unit_ratio ) + ','
        + std::to_string( type.max_unit_ratio ) + ',' + vod( type.extensions ) + ")::hive.smt_capped_generation_policy";
    }
  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_setup_operation& op )const
  {
    static smt_generation_policy_visitor sgpv{ *this };

    return "('"
      + op.control_account + "'," + std::to_string( op.symbol.asset_num ) + ',' + std::to_string( op.max_supply ) + ','
      + op.initial_generation_policy.visit( sgpv ) + ',' + this->operator()( op.contribution_begin_time ) + ','
      + this->operator()( op.contribution_end_time ) + ',' + this->operator()( op.launch_time ) + ','
      + std::to_string( op.hive_units_soft_cap.value ) + ',' + std::to_string( op.hive_units_hard_cap.value ) + ','
      + this->operator()( op.extensions )
      + ")::hive.smt_setup_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_setup_emissions_operation& op )const
  {
    return "('"
      + op.control_account + "'," + std::to_string( op.symbol.asset_num ) + ',' + this->operator()( op.schedule_time ) + ",ROW("
      + this->operator()( op.emissions_unit.token_unit ) + ")," + std::to_string( op.interval_seconds ) + ','
      + std::to_string( op.interval_count ) + ',' + this->operator()( op.lep_time ) + ',' + this->operator()( op.rep_time ) + ','
      + this->operator()( op.lep_abs_amount ) + ',' + this->operator()( op.rep_abs_amount ) + ',' + std::to_string( op.lep_rel_amount_numerator ) + ','
      + std::to_string( op.rep_rel_amount_numerator ) + ',' + std::to_string( op.rel_amount_denom_bits ) + ',' + std::to_string( op.remove ) + ','
      + this->operator()( op.extensions )
      + ")::hive.smt_setup_emissions_operation";
  }

  struct smt_setup_parameter_visitor
  {
    using result_type = std::string;

    result_type operator()( const hp::smt_param_allow_voting& type )const
    {
      return "ROW(" + std::to_string( type.value ) + ")::hive.smt_param_allow_voting";
    }
  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_set_setup_parameters_operation& op )const
  {
    static constexpr smt_setup_parameter_visitor sspv;

    std::string str_op = "('" + op.control_account + "'," + std::to_string( op.symbol.asset_num ) + ",ARRAY[";

    for( auto it = op.setup_parameters.begin(); it != op.setup_parameters.end(); ++it )
    {
      if( it != op.setup_parameters.begin() )
        str_op += ',';

      str_op += it->visit( sspv );
    }

    return str_op + "]::hive_smt_setup_parameter[]," + this->operator()( op.extensions ) + ")::hive.smt_set_setup_parameters_operation";
  }

  struct smt_runtime_parameter_visitor
  {
    using result_type = std::string;

    const result_type& operator()( const hp::curve_id& type )const
    {
      static std::string curve_ids[] = {
        "'quadratic'",
        "'bounded_curation'",
        "'linear'",
        "'square_root'",
        "'convergent_linear'",
        "'convergent_square_root'"
      };

      switch( type )
      {
        case hp::curve_id::quadratic:
          return curve_ids[ 0 ];
        case hp::curve_id::bounded_curation:
          return curve_ids[ 1 ];
        case hp::curve_id::linear:
          return curve_ids[ 2 ];
        case hp::curve_id::square_root:
          return curve_ids[ 3 ];
        case hp::curve_id::convergent_linear:
          return curve_ids[ 4 ];
        case hp::curve_id::convergent_square_root:
          return curve_ids[ 5 ];
      }

      FC_ASSERT( false, "curve_id not supported: ${cid}", ("cid", type) );
    }

    result_type operator()( const hp::smt_param_windows_v1& type )const
    {
      return '(' + std::to_string( type.cashout_window_seconds ) + ','
        + std::to_string( type.reverse_auction_window_seconds ) + ")::hive.smt_param_windows_v1";
    }

    result_type operator()( const hp::smt_param_vote_regeneration_period_seconds_v1& type )const
    {
      return '(' + std::to_string( type.vote_regeneration_period_seconds ) + ','
        + std::to_string( type.votes_per_regeneration_period ) + ")::hive.smt_param_vote_regeneration_period_seconds_v1";
    }

    result_type operator()( const hp::smt_param_rewards_v1& type )const
    {
      return '(' + type.content_constant.operator std::string() + ',' + std::to_string( type.percent_curation_rewards ) + ','
        + this->operator()( type.author_reward_curve ) + ',' + this->operator()( type.curation_reward_curve ) + ")::hive.smt_param_rewards_v1";
    }

    result_type operator()( const hp::smt_param_allow_downvotes& type )const
    {
      return "ROW(" + std::to_string( type.value ) + ")::hive.smt_param_allow_downvotes";
    }
  };

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_set_runtime_parameters_operation& op )const
  {
    static constexpr smt_runtime_parameter_visitor srpv;

    std::string str_op = "('" + op.control_account + "'," + std::to_string( op.symbol.asset_num ) + ",ARRAY[";

    for( auto it = op.runtime_parameters.begin(); it != op.runtime_parameters.end(); ++it )
    {
      if( it != op.runtime_parameters.begin() )
        str_op += ',';

      str_op += it->visit( srpv );
    }

    return str_op + "]::hive_smt_runtime_parameter[]," + this->operator()( op.extensions ) + ")::hive.smt_set_runtime_parameters_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_create_operation& op )const
  {
    return "('"
      + op.control_account + "'," + std::to_string( op.symbol.asset_num ) + ',' + this->operator()( op.smt_creation_fee ) + ','
      + std::to_string( op.precision ) + ',' + this->operator()( op.extensions )
      + ")::hive.smt_create_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::smt_contribute_operation& op )const
  {
    return "('"
      + op.contributor + "'," + std::to_string( op.symbol.asset_num ) + ',' + std::to_string( op.contribution_id ) + ','
      + this->operator()( op.contribution ) + ',' + this->operator()( op.extensions )
      + ")::hive.smt_contribute_operation";
  }

#endif

  /// virtual operations below this point
  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_convert_request_operation& op )const
  {
    return "('"
      + op.owner + "'," + std::to_string( op.requestid ) + ',' + this->operator()( op.amount_in ) + ',' + this->operator()( op.amount_out )
      + ")::hive.fill_convert_request_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::author_reward_operation& op )const
  {
    return "('"
      + op.author + "'," + escape( op.permlink ) + ',' + this->operator()( op.hbd_payout ) + ',' + this->operator()( op.hive_payout ) + ','
      + this->operator()( op.vesting_payout ) + ',' + this->operator()( op.curators_vesting_payout ) + ',' + std::to_string( op.payout_must_be_claimed )
      + ")::hive.author_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::curation_reward_operation& op )const
  {
    return "('"
      + op.curator + "'," + this->operator()( op.reward ) + ",'" + op.comment_author + "',"
      + escape( op.comment_permlink ) + ',' + std::to_string( op.payout_must_be_claimed )
      + ")::hive.curation_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_reward_operation& op )const
  {
    return "('"
      + op.author + "'," + escape( op.permlink ) + ',' + this->operator()( op.payout ) + ',' + std::to_string( op.author_rewards.value ) + ','
      + this->operator()( op.total_payout_value ) + ',' + this->operator()( op.curator_payout_value ) + ',' + this->operator()( op.beneficiary_payout_value ) + ','
      + ")::hive.comment_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::liquidity_reward_operation& op )const
  {
    return "('"
      + op.owner + "'," + this->operator()( op.payout )
      + ")::hive.liquidity_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::interest_operation& op )const
  {
    return "('"
      + op.owner + "'," + this->operator()( op.interest )
      + ")::hive.interest_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_vesting_withdraw_operation& op )const
  {
    return "('"
      + op.from_account + "','" + op.to_account + "'," + this->operator()( op.withdrawn ) + ','
      + this->operator()( op.deposited )
      + ")::hive.fill_vesting_withdraw_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_order_operation& op )const
  {
    return "('"
      + op.current_owner + "'," + std::to_string( op.current_orderid ) + ',' + this->operator()( op.current_pays ) + ",'"
      + op.open_owner + "'," + std::to_string( op.open_orderid ) + ',' + this->operator()( op.open_pays )
      + ")::hive.fill_order_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::shutdown_witness_operation& op )const
  {
    return "ROW('"
      + op.owner
      + "')::hive.shutdown_witness_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_transfer_from_savings_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "'," + this->operator()( op.amount ) + ',' + std::to_string( op.request_id ) + ',' + escape( op.memo )
      + ")::hive.fill_transfer_from_savings_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::hardfork_operation& op )const
  {
    return "ROW("
      + std::to_string( op.hardfork_id )
      + ")::hive.hardfork_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_payout_update_operation& op )const
  {
    return "('"
      + op.author + "'," + escape( op.permlink )
      + ")::hive.comment_payout_update_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::return_vesting_delegation_operation& op )const
  {
    return "('"
      + op.account + "'," + this->operator()( op.vesting_shares )
      + ")::hive.return_vesting_delegation_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::comment_benefactor_reward_operation& op )const
  {
    return "('"
      + op.benefactor + "','" + op.author + "'," + escape( op.permlink ) + ',' + this->operator()( op.hbd_payout ) + ','
      + this->operator()( op.hive_payout ) + ',' + this->operator()( op.vesting_payout )
      + ")::hive.comment_benefactor_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::producer_reward_operation& op )const
  {
    return "('"
      + op.producer + "'," + this->operator()( op.vesting_shares )
      + ")::hive.producer_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::clear_null_account_balance_operation& op )const
  {
    std::string str_op = "ROW(ARRAY[";

    for( auto it = op.total_cleared.begin(); it != op.total_cleared.end(); ++it )
    {
      if( it != op.total_cleared.begin() )
        str_op += ',';

      str_op += this->operator()( *it );
    }

    return str_op + "]::hive.asset[])::hive.clear_null_account_balance_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::proposal_pay_operation& op )const
  {
    return '('
      + std::to_string( op.proposal_id ) + ",'" + op.receiver + "','" + op.payer + "'," + this->operator()( op.payment ) + ','
      + escape_raw( op.trx_id ) + ',' + std::to_string( op.op_in_trx )
      + ")::hive.proposal_pay_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::sps_fund_operation& op )const
  {
    return "('"
      + op.fund_account + "'," + this->operator()( op.additional_funds )
      + ")::hive.sps_fund_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::hardfork_hive_operation& op )const
  {
    std::string str_op = "('" + op.account + "','" + op.treasury + "',ARRAY[";

    for( auto it = op.other_affected_accounts.begin(); it != op.other_affected_accounts.end(); ++it )
    {
      if( it != op.other_affected_accounts.begin() )
        str_op += ',';

      str_op += '\'' + it->operator std::string() + '\'';
    }

    return str_op + "]::hive.account_name_type[]," + this->operator()( op.hbd_transferred ) + ','
      + this->operator()( op.hive_transferred ) + ',' + this->operator()( op.vests_converted ) + ','
      + this->operator()( op.total_hive_from_vests ) + ")::hive.hardfork_hive_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::hardfork_hive_restore_operation& op )const
  {
    return "('"
      + op.account + "','" + op.treasury + "'," + this->operator()( op.hbd_transferred ) + ',' + this->operator()( op.hive_transferred )
      + ")::hive.hardfork_hive_restore_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::delayed_voting_operation& op )const
  {
    return "('"
      + op.voter + "'," + std::to_string( op.votes.value )
      + ")::hive.delayed_voting_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::consolidate_treasury_balance_operation& op )const
  {
    std::string str_op = "ROW(ARRAY[";

    for( auto it = op.total_moved.begin(); it != op.total_moved.end(); ++it )
    {
      if( it != op.total_moved.begin() )
        str_op += ',';

      str_op += this->operator()( *it );
    }

    return str_op + "]::hive.asset[])::hive.consolidate_treasury_balance_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::effective_comment_vote_operation& op )const
  {
    return "('"
      + op.voter + "','" + op.author + "'," + escape( op.permlink ) + ',' + std::to_string( op.weight ) + ',' + std::to_string( op.rshares ) + ','
      + std::to_string( op.total_vote_weight ) + ',' + this->operator()( op.pending_payout )
      + ")::hive.effective_comment_vote_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::ineffective_delete_comment_operation& op )const
  {
    return "('"
      + op.author + "'," + escape( op.permlink )
      + ")::hive.ineffective_delete_comment_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::sps_convert_operation& op )const
  {
    return "('"
      + op.fund_account + "'," + this->operator()( op.hive_amount_in ) + ',' + this->operator()( op.hbd_amount_out )
      + ")::hive.sps_convert_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::expired_account_notification_operation& op )const
  {
    return "ROW('"
      + op.account
      + "')::hive.expired_account_notification_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::changed_recovery_account_operation& op )const
  {
    return "('"
      + op.account + "','" + op.old_recovery_account + "','" + op.new_recovery_account
      + "')::hive.changed_recovery_account_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::transfer_to_vesting_completed_operation& op )const
  {
    return "('"
      + op.from_account + "','" + op.to_account + "'," + this->operator()( op.hive_vested ) + ',' + this->operator()( op.vesting_shares_received )
      + ")::hive.transfer_to_vesting_completed_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::pow_reward_operation& op )const
  {
    return "('"
      + op.worker + "'," + this->operator()( op.reward )
      + ")::hive.pow_reward_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::vesting_shares_split_operation& op )const
  {
    return "('"
      + op.owner + "'," + this->operator()( op.vesting_shares_before_split ) + ',' + this->operator()( op.vesting_shares_after_split )
      + ")::hive.vesting_shares_split_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::account_created_operation& op )const
  {
    return "('"
      + op.new_account_name + "','" + op.creator + "'," + this->operator()( op.initial_vesting_shares ) + ',' + this->operator()( op.initial_delegation )
      + ")::hive.account_created_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_collateralized_convert_request_operation& op )const
  {
    return "('"
      + op.owner + "'," + std::to_string( op.requestid ) + ',' + this->operator()( op.amount_in ) + ','
      + this->operator()( op.amount_out ) + ',' + this->operator()( op.excess_collateral )
      + ")::hive.fill_collateralized_convert_request_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::system_warning_operation& op )const
  {
    return "ROW('"
      + op.message
      + "')::hive.system_warning_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::fill_recurrent_transfer_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + "'," + this->operator()( op.amount ) + ',' + escape( op.memo ) + ',' + std::to_string( op.remaining_executions )
      + ")::hive.fill_recurrent_transfer_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::failed_recurrent_transfer_operation& op )const
  {
    return "('"
      + op.from + "','" + op.to + ',' + this->operator()( op.amount ) + ',' + escape( op.memo )
      + ',' + std::to_string( op.consecutive_failures ) + ',' + std::to_string( op.remaining_executions ) + ',' + std::to_string( op.deleted )
      + ")::hive.failed_recurrent_transfer_operation";
  }

  variant_operation_deserializer::result_type variant_operation_deserializer::operator()( const hp::limit_order_cancelled_operation& op )const
  {
    return "('"
      + op.seller + "'," + std::to_string( op.orderid ) + ',' + this->operator()( op.amount_back )
      + ")::hive.limit_order_cancelled_operation";
  }

}
