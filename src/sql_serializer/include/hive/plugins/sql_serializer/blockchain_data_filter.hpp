#pragma once

#include <hive/chain/util/data_filter.hpp>
#include<set>

namespace hive::plugins::sql_serializer {

  using hive::plugins::account_filter;
  using hive::protocol::account_name_type;

  struct account_tracker_base
  {
    virtual void fill( const boost::program_options::variables_map& options, const string& option_name ) = 0;
    virtual bool empty() = 0;
    virtual bool is_tracked_account( const account_name_type& name ) = 0;
  };
  template<bool empty>
  struct account_tracker: public account_tracker_base
  {
    account_filter filter;

    account_tracker( const string& _filter_name ) : filter( _filter_name ){}

    void fill( const boost::program_options::variables_map& options, const string& option_name ) override
    {
      filter.fill( options, option_name );
    }
    bool empty() override
    {
      return filter.empty();
    }
    bool is_tracked_account( const account_name_type& name ) override
    {
      return filter.is_tracked_account( name );
    }
  };
  template<>
  struct account_tracker<true>: public account_tracker_base
  {
    account_tracker(){}

    void fill( const boost::program_options::variables_map& options, const string& option_name ) override {}
    bool empty() override { return true; }
    bool is_tracked_account( const account_name_type& name ) override { return true; }
  };

  struct operation_tracker_base
  {
    virtual void fill( const boost::program_options::variables_map& options, const string& option_name ) = 0;
    virtual bool empty() = 0;
    virtual bool is_tracked_operation( const operation& op ) = 0;
  };
  template<bool empty, typename filter_type>
  struct operation_tracker: public operation_tracker_base
  {
    filter_type filter;

    operation_tracker( const string& _filter_name, const operation_helper& _op_helper )
    : filter( _filter_name, _op_helper ){}

    void fill( const boost::program_options::variables_map& options, const string& option_name ) override
    {
      filter.fill( options, option_name );
    }
    bool empty() override
    {
      return filter.empty();
    }
    bool is_tracked_operation( const operation& op ) override
    {
      return filter.is_tracked_operation( op );
    }
  };
  template<typename filter_type>
  struct operation_tracker<true, filter_type>: public operation_tracker_base
  {
    operation_tracker(){}

    void fill( const boost::program_options::variables_map& options, const string& option_name ) override {}
    bool empty() override { return true; }
    bool is_tracked_operation( const operation& op ) override { return true; }
  };

  struct blockchain_data_filter
  {
    virtual bool is_enabled() const = 0;
    virtual bool is_tracked_account( const account_name_type& name ) const = 0;
    virtual bool is_tracked_operation( const operation& op ) const = 0;
  };

  struct blockchain_filter: public blockchain_data_filter
  {
    private:

      using ptr_account_tracker_base    = std::unique_ptr<account_tracker_base>;
      using ptr_operation_tracker_base  = std::unique_ptr<operation_tracker_base>;

      bool                  enabled = false;

      std::set<int64_t>     trx_in_block_filter_accepted;

      operation_helper      op_helper;

      ptr_account_tracker_base    accounts_filter_tracker;
      ptr_operation_tracker_base  operations_filter_tracker;
      ptr_operation_tracker_base  operations_body_filter_tracker;

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
