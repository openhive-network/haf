#pragma once

#include <boost/signals2.hpp>

#include <limits>
#include <memory>
#include <string>

namespace hive::chain{
  class database;
}

namespace hive::plugins::sql_serializer {
  class data_dumper;
  class sql_serializer_plugin;
  struct cached_data_t;

  class indexation_state
  {
    public:
      class flush_trigger;
      using enable_indexes_callback = std::function< void() >;
      static constexpr auto NO_IRREVERSIBLE_BLOCK = std::numeric_limits< int32_t >::max();

      indexation_state(
          const sql_serializer_plugin& main_plugin
        , hive::chain::database& chain_db
        , std::string db_url
        , enable_indexes_callback enable_indexes
        , uint32_t psql_transactions_threads_number
        , uint32_t psql_operations_threads_number
        , uint32_t psql_account_operations_threads_number
      );
      ~indexation_state() = default;
      indexation_state& operator=( indexation_state& ) = delete;
      indexation_state( indexation_state& ) = delete;
      indexation_state& operator=( indexation_state&& ) = delete;
      indexation_state( indexation_state&& ) = delete;

      /* functions which change state of syncing
       * Syncing state-transition table:
       * P2P is starting state
       *          | on_pre_reindex  | on_post_reindex | on_end_of_syncing |
       * P2P      |     REINDEX     | ASSERT( false ) |       LIVE        |
       * REINDEX  | ASSERT( false ) |       P2P       |  ASSERT( false )  |
       * LIVE     | ASSERT( false ) | ASSERT( false ) |  ASSERT( false )  |
       */
      void on_pre_reindex( cached_data_t& cached_data, int last_block_num );
      void on_post_reindex( cached_data_t& cached_data, int last_block_num );
      void on_end_of_syncing( cached_data_t& cached_data, int last_block_num );

      // call when fork occurs, block_num -> first abanoned block
      void on_switch_fork( cached_data_t& cached_data, uint32_t block_num );

      // trying triggers flushing data to databes, cahed data ma by modified (shrinked) or not
      void trigger_data_flush( cached_data_t& cached_data, int last_block_num );

    private:
      enum class INDEXATION{ P2P, REINDEX, LIVE };
      void update_state( INDEXATION state, cached_data_t& cached_data, uint32_t last_block_num );

      void on_irreversible_block( uint32_t block_num );
      void flush_all_data_to_reversible( cached_data_t& cached_data );
      void force_trigger_flush_with_all_data( cached_data_t& cached_data, int last_block_num );
      void enable_irreversible_indexes();

    private:
      const sql_serializer_plugin& _main_plugin;
      hive::chain::database& _chain_db;
      const std::string _db_url;
      const uint32_t _psql_transactions_threads_number;
      const uint32_t _psql_operations_threads_number;
      const uint32_t _psql_account_operations_threads_number;

      boost::signals2::connection _on_irreversible_block_conn;
      INDEXATION _state{ INDEXATION::P2P };
      std::shared_ptr< data_dumper > _dumper;
      std::shared_ptr< flush_trigger > _trigger;
      int32_t _irreversible_block_num;
      enable_indexes_callback _enable_indexes_callback;
  };

} // namespace hive::plugins::sql_serializer
