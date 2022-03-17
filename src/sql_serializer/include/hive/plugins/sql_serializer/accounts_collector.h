#pragma once

#include <hive/plugins/sql_serializer/sql_serializer_objects.hpp>
#include <hive/plugins/sql_serializer/filter_collector.hpp>
#include <hive/plugins/sql_serializer/cached_data.h>

#include <hive/chain/database.hpp>

#include <map>
#include <vector>

namespace hive::plugins::sql_serializer {

  struct accounts_collector_base
  {
    protected:
      virtual void on_collect( const hive::protocol::operation& op, const flat_set<hive::protocol::account_name_type>& impacted ){}
      virtual bool on_before_new_account( const hive::protocol::account_name_type& account_name ){ return true; }
      virtual bool on_before_new_operation( const hive::protocol::account_name_type& account_name ){ return true; }

    public:

      virtual ~accounts_collector_base(){}
      virtual bool is_op_accepted() const { return true; }
  };

  struct accounts_collector: public accounts_collector_base
    {
    typedef void result_type;

    accounts_collector( hive::chain::database& chain_db , cached_data_t& cached_data )
      : _chain_db(chain_db), _cached_data(cached_data) {}

    virtual ~accounts_collector(){}

    void collect(int64_t operation_id, const hive::protocol::operation& op, uint32_t block_num);

    void operator()(const hive::protocol::account_create_operation& op);

    void operator()(const hive::protocol::account_create_with_delegation_operation& op);

    void operator()(const hive::protocol::create_claimed_account_operation& op);

    void operator()(const hive::protocol::pow_operation& op);

    void operator()(const hive::protocol::pow2_operation& op);

    void operator()(const hive::protocol::account_created_operation& op);

    template< typename T >
    void operator()(const T& op)
    {
      for( const auto& account_name : _impacted )
        on_new_operation(account_name, _processed_operation_id);
    }

    private:
      void process_account_creation_op(fc::optional<hive::protocol::account_name_type> impacted_account);

      void on_new_account(const hive::protocol::account_name_type& account_name);

      void on_new_operation(const hive::protocol::account_name_type& account_name, int64_t operation_id);

    private:
      hive::chain::database& _chain_db;
      cached_data_t& _cached_data;
      int64_t _processed_operation_id = -1;
      uint32_t _block_num = 0;

      fc::optional<int64_t> _creation_operation_id;
      flat_set<hive::protocol::account_name_type> _impacted;
    };

    struct filtered_accounts_collector: public accounts_collector
    {
      private:
        filter_collector _filter_collector;

      protected:
        void on_collect( const hive::protocol::operation& op, const flat_set<hive::protocol::account_name_type>& impacted ) override;
        bool on_before_new_account( const hive::protocol::account_name_type& account_name ) override;
        bool on_before_new_operation( const hive::protocol::account_name_type& account_name ) override;

      public:
        filtered_accounts_collector( hive::chain::database& chain_db , cached_data_t& cached_data, const blockchain_data_filter& filter );
        virtual ~filtered_accounts_collector(){}

        bool is_op_accepted() const override;
    };

} // namespace hive::plugins::sql_serializer
