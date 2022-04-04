#pragma once

#include <hive/chain/util/data_filter.hpp>
#include<set>

namespace hive::plugins::sql_serializer {

  using hive::plugins::account_filter;
  using hive::protocol::account_name_type;

  struct blockchain_data_filter
  {
    virtual bool is_enabled() const = 0;
    virtual bool is_tracked_account( const account_name_type& name ) const = 0;
    virtual bool is_tracked_operation( const operation& op ) const = 0;
  };

  struct blockchain_filter: public blockchain_data_filter
  {
    private:

      template<typename filter_type>
      using ptr_proxy_tracker           = std::unique_ptr<filter_type>;

      using ptr_account_tracker         = ptr_proxy_tracker<account_filter>;
      using ptr_operations_tracker      = ptr_proxy_tracker<operation_filter>;
      using ptr_operations_body_tracker = ptr_proxy_tracker<operation_body_filter>;

      bool                  enabled = false;

      std::set<int64_t>     trx_in_block_filter_accepted;

      operation_helper      op_helper;

      ptr_account_tracker         accounts_filter_tracker;
      ptr_operations_tracker      operations_filter_tracker;
      ptr_operations_body_tracker operations_body_filter_tracker;

    public:

      blockchain_filter( bool _enabled, const type_extractor::operation_extractor& op_extractor )
                                : enabled( _enabled ), op_helper( op_extractor )
      {}

      bool is_enabled() const override;
      bool is_trx_accepted( int64_t trx_in_block ) const;

      bool is_tracked_account( const account_name_type& name ) const override;
      bool is_tracked_operation( const operation& op ) const override;

      void remember_trx_id( int64_t trx_in_block );
      void fill(  const boost::program_options::variables_map& options,
                  const std::string& tracked_accounts,
                  const std::string& tracked_operations,
                  const std::string& tracked_operation_body_filters );
      void clear();
  };

} // namespace hive::plugins::sql_serializer
