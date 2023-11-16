#pragma once

#include <hive/plugins/sql_serializer/indexes_controler.h>

#include <boost/signals2.hpp>
#include <fc/time.hpp>

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
      static constexpr auto NO_IRREVERSIBLE_BLOCK = std::numeric_limits< int32_t >::max();

      indexation_state(
          const sql_serializer_plugin& main_plugin
        , hive::chain::database& chain_db
        , std::string db_url
        , appbase::application& app
        , uint32_t psql_transactions_threads_number
        , uint32_t psql_operations_threads_number
        , uint32_t psql_account_operations_threads_number
        , uint32_t psql_index_threshold
        , uint32_t psql_livesync_threshold
        , uint32_t psql_first_block
      );
      ~indexation_state() = default;
      indexation_state& operator=( indexation_state& ) = delete;
      indexation_state( indexation_state& ) = delete;
      indexation_state& operator=( indexation_state&& ) = delete;
      indexation_state( indexation_state&& ) = delete;

      void on_pre_reindex( cached_data_t& cached_data, int last_block_num, uint32_t number_of_blocks_to_add );
      void on_post_reindex( cached_data_t& cached_data, uint32_t last_block_num, uint32_t _stop_replay_at );
      void on_end_of_syncing( cached_data_t& cached_data, int last_block_num );
      void on_first_block( int last_block_num );
      void on_block( int last_block_num );

      // call when fork occurs, block_num -> first abanoned block
      void on_switch_fork( cached_data_t& cached_data, uint32_t block_num );

      // trying triggers flushing data to databes, cahed data ma by modified (shrinked) or not
      void trigger_data_flush( cached_data_t& cached_data, int last_block_num );

      // is current state allow to collect blocks
      bool collect_blocks() const;

    private:
      static constexpr uint32_t COLLECT_BLOCKS_MASK = 0xA0;
      enum class INDEXATION : uint32_t {
           START=0x00
         , WAIT=0x01
         , REINDEX_WAIT=0x02
         , REINDEX=0xA0
         , P2P=0xA1
         , LIVE=0xA2
      };
      static constexpr auto UNKNOWN = std::numeric_limits< uint32_t >::max();
      void update_state( INDEXATION state, cached_data_t& cached_data, uint32_t last_block_num, uint32_t number_of_blocks_to_add = UNKNOWN );

      void on_irreversible_block( uint32_t block_num );
      void flush_all_data_to_reversible( cached_data_t& cached_data );
      void force_trigger_flush_with_all_data( cached_data_t& cached_data, int last_block_num );
      bool can_move_to_livesync() const;
      uint32_t expected_number_of_blocks_to_sync() const;
      bool is_any_block_dumped();
      void dump_all_accounts();
    private:
      const sql_serializer_plugin& _main_plugin;
      hive::chain::database& _chain_db;
      const std::string _db_url;
      appbase::application& theApp;
      const uint32_t _psql_transactions_threads_number;
      const uint32_t _psql_operations_threads_number;
      const uint32_t _psql_account_operations_threads_number;
      const uint32_t _psql_livesync_threshold;
      const uint32_t _psql_first_block;
      bool _was_blocks_already_dumped_during_start;

      boost::signals2::connection _on_irreversible_block_conn;
      INDEXATION _state{ INDEXATION::P2P };
      std::shared_ptr< data_dumper > _dumper;
      std::shared_ptr< flush_trigger > _trigger;
      int32_t _irreversible_block_num;
      indexes_controler _indexes_controler;

      fc::time_point _start_state_time;
  };

} // namespace hive::plugins::sql_serializer
