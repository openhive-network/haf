#include "hive/plugins/sql_serializer/block_num_rendezvous_trigger.hpp"

#include "fc/exception/exception.hpp"

namespace hive { namespace plugins { namespace sql_serializer {
  block_num_rendezvous_trigger::block_num_rendezvous_trigger(
      uint32_t _number_of_threads
    , TRIGGERRED_FUNCTION _triggered_function
  )
  : m_number_of_threads( _number_of_threads )
  , m_triggered_function( std::move( _triggered_function ) )
  {
    dlog( "rendezvous trigger will wait for ${thread}", ( "thread", m_number_of_threads ) );
    if ( m_number_of_threads < 1 ) {
      FC_THROW( "Incorrect number of threads" );
    }

    if ( !m_triggered_function ) {
      FC_THROW( "No trigger function" );
    }
  }

  void
  block_num_rendezvous_trigger::report_complete_thread_stage( BLOCK_NUM _stage_block_num ) {
    // Fast path for single thread
    if ( m_number_of_threads == 1 ) {
      m_triggered_function( _stage_block_num );
      return;
    }

    bool should_trigger = false;
    auto on_existing = [&](auto& entry) {
      auto& completed_count = entry.second;
      ++completed_count;
      FC_ASSERT(completed_count <= m_number_of_threads,
        "More threads reported for block ${b} (${c}) than expected (${n})",
        ("b", entry.first)("c", completed_count)("n", m_number_of_threads));
      if (completed_count == m_number_of_threads) {
        should_trigger = true;
      }
    };

    m_completed_threads.insert_or_visit(
      std::pair<BLOCK_NUM, NUMBER_OF_COMPLETED_THREADS>{ _stage_block_num, 1 },
      on_existing
    );

    if ( should_trigger ) {
      m_completed_threads.erase( _stage_block_num );
      m_triggered_function( _stage_block_num );
      ilog( "Dump whole block ${i}", ( "i", _stage_block_num ) );
    }
  }
}}} // namespace hive::plugins::sql_serializer
