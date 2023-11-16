#include <hive/plugins/sql_serializer/all_accounts_dumper.h>

#include <hive/plugins/sql_serializer/chunks_for_writers_spillter.h>
#include <hive/plugins/sql_serializer/sql_serializer_objects.hpp>
#include <hive/plugins/sql_serializer/table_data_writer.h>
#include <hive/plugins/sql_serializer/tables_descriptions.h>

#include <appbase/application.hpp>

#include <hive/chain/account_object.hpp>
#include <hive/chain/database.hpp>

#include <vector>
#include <string>

using hive::chain::account_index;
using hive::chain::by_id;




namespace hive::plugins::sql_serializer {

  using accounts_data_container_t_writer = chunks_for_sql_writers_splitter<
    table_data_writer<
      hive_accounts<
        container_view< std::vector<PSQL::processing_objects::account_data_t> >
      >
    >
  >;

  all_accounts_dumper::all_accounts_dumper(
        uint8_t number_of_threads
      , const std::string& dburl
      , hive::chain::database& chain_db
      , appbase::application& app
  ) : _dburl( dburl )
    , _app( app )
  {
    auto start_state_time = fc::time_point::now();
    ilog( "Dump all accounts is starting...");

    // Always truncate account, maybe the table contains not finished
    // dump from previous hived run. If there is no data then truncate won't be costly
    // , but making it always will make the code simpler
    queries_commit_data_processor disable_fk_and_indexes(
      _dburl
      , "Disable accounts FK and indexes"
      , [](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
        tx.exec("truncate hive.accounts");
        return data_processor::data_processing_status();
      }
      , nullptr
      , _app
    );

    auto set_consistent_block = [](block_num_rendezvous_trigger::BLOCK_NUM _block_num){return;};
    auto api_trigger = std::make_shared< block_num_rendezvous_trigger >(
      number_of_threads, set_consistent_block );

    accounts_data_container_t_writer writer(
        number_of_threads
      , dburl
      , "All accounts data writer"
      , api_trigger
      , app
    );

    auto constexpr MAX_NUMBER_OF_ACCOUNTS_IN_ONE_TURN = 10000;
    auto constexpr BLOCK_NUM_PLACEHOLDER = 1;
    auto constexpr BLOCK_NUM_SINK = 0;

    std::vector<PSQL::processing_objects::account_data_t> data_to_dump;
    data_to_dump.reserve( MAX_NUMBER_OF_ACCOUNTS_IN_ONE_TURN );

    int32_t id = -1;
    for( const auto& account : chain_db.get_index< account_index, by_id >() ) {
      ++id;
      data_to_dump.emplace_back( id, account.get_name(), BLOCK_NUM_SINK );
      if ( id % MAX_NUMBER_OF_ACCOUNTS_IN_ONE_TURN == 0 ) {
        ilog( "Dump all accounts is dumping batch ${b}", ("b", id / MAX_NUMBER_OF_ACCOUNTS_IN_ONE_TURN ));
        writer.trigger( std::move( data_to_dump ), BLOCK_NUM_PLACEHOLDER );
        data_to_dump = std::vector<PSQL::processing_objects::account_data_t>();
        data_to_dump.reserve( MAX_NUMBER_OF_ACCOUNTS_IN_ONE_TURN );
      }
    }

    ilog( "Dump all accounts is finishing dumping last batch" );
    if ( data_to_dump.size() > 0 ) {
      writer.trigger( std::move( data_to_dump ), BLOCK_NUM_PLACEHOLDER );
    }

    writer.join();
    ilog( "Dump all accounts ended. Dumping ${d} accounts lasted ${t} s", ("d", id)("t",(fc::time_point::now() - start_state_time).to_seconds() ) );
  }

  all_accounts_dumper::~all_accounts_dumper() {
  }

} // namespace hive::plugins::sql_serializer
