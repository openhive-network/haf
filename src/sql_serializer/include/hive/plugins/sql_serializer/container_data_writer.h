#pragma once

#include <hive/plugins/sql_serializer/block_num_rendezvous_trigger.hpp>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>
#include <hive/plugins/sql_serializer/tables_descriptions.h>

#include <fc/exception/exception.hpp>

namespace hive::plugins::sql_serializer {
  /**
   * @brief Common implementation of data writer to be used for all SQL entities.
   *
   * @tparam DataContainer temporary container providing a data chunk.
   * @tparam TupleConverter a functor to convert volatile representation (held in the DataContainer) into SQL representation
   *                        TupleConverter must match to function interface:
   *                        std::string(pqxx::work& tx, typename DataContainer::const_reference)
   *
  */
  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, typename Processor = queries_commit_data_processor >
    class container_data_writer
      {
      public:
        using DataContainerType = DataContainer;
        using DataProcessor = Processor;

        container_data_writer(
            std::string psqlUrl
          , std::string description
          , std::string short_description
          , std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger
          , appbase::application& app
        ) {
          _processor = std::make_unique<Processor>(psqlUrl, std::move(description), std::move(short_description), flush_replayed_data, _randezvous_trigger, app);
        }

        container_data_writer(
            std::function< void(std::string&&) > string_callback
          , std::string description
          , std::string short_description
          , std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger
          , appbase::application& app
        ) {
          _processor = std::make_unique<Processor>(string_callback, std::move(description), std::move(short_description), flush_scalar_live_data, _randezvous_trigger, app);
        }

        void trigger(DataContainer&& data, uint32_t last_block_num);
        void complete_data_processing();
        void join();

      private:
        using data_processing_status = data_processor::data_processing_status;
        using data_chunk_ptr = data_processor::data_chunk_ptr;

        static data_processing_status flush_replayed_data(const data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx);
        static data_processing_status flush_scalar_live_data(const data_chunk_ptr& dataPtr, std::function< void(std::string&&) > callback);


      private:
        class chunk : public data_processor::data_chunk
          {
          public:
            chunk( DataContainer&& data ) : _data(std::move(data)) {}
            ~chunk() = default;

            DataContainer _data;
          };

      private:
        std::unique_ptr< Processor > _processor;
      };

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, typename Processor>
  inline void
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, Processor >::trigger(DataContainer&& data, uint32_t last_block_num)
  {
    if(data.empty() == false)
    {
      _processor->trigger(std::make_unique<chunk>(std::move(data)), last_block_num);
    } else {
      _processor->only_report_batch_finished( last_block_num );
    }

    FC_ASSERT(data.empty(), "DATA empty 1");
  }

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, typename Processor>
  inline void
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, Processor >::complete_data_processing()
  {
    _processor->complete_data_processing();
  }

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, typename Processor>
  inline void
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, Processor >::join()
  {
    _processor->join();
  }

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, typename Processor>
  inline typename container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, Processor >::data_processing_status
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, Processor >::flush_replayed_data(const data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx)
  {
    const chunk* holder = static_cast<const chunk*>(dataPtr.get());
    data_processing_status processingStatus;

    const DataContainer& data = holder->_data;
    FC_ASSERT(!data.empty(), "Data empty 2");

    tx.run_in_transaction([&](pqxx::work& work) {
      pqxx::stream_to stream = pqxx::stream_to::raw_table(work, TABLE_NAME, COLUMN_LIST);
      for (auto i = data.cbegin(); i != data.cend(); ++i) 
        write_row_to_stream(stream, *i);
      stream.complete();
    });

    processingStatus.first += data.size();
    processingStatus.second = true;

    return processingStatus;
  }

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, typename Processor>
  inline typename container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, Processor >::data_processing_status
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, Processor >::flush_scalar_live_data(const data_chunk_ptr& dataPtr, std::function< void(std::string&&) > callback)
  {
    const chunk* holder = static_cast<const chunk*>(dataPtr.get());
    data_processing_status processingStatus;

    TupleConverter conv;

    const DataContainer& data = holder->_data;

    FC_ASSERT(data.empty() == false, "Data empty 3");

    std::string query = "";

    auto dataI = data.cbegin();
    query += '(' + conv(*dataI) + ")\n";

    for(++dataI; dataI != data.cend(); ++dataI)
    {
      query += ",(" + conv(*dataI) + ")\n";
    }

    callback( std::move(query) );

    processingStatus.first += data.size();
    processingStatus.second = true;

    return processingStatus;
  }

  template< typename Writer >
  inline std::exception_ptr
  join_writers_impl( Writer& writer ) try {
    try{
      writer.join();
    }
    FC_CAPTURE_AND_RETHROW()
    return nullptr;
  } catch( ... ) {
    return std::current_exception();
  }

  template< typename Writer, typename... Writers >
  inline std::exception_ptr
  join_writers_impl( Writer& writer, Writers& ...writers ) {
    std::exception_ptr current_exception = join_writers_impl( writer );;
    auto next_exception = join_writers_impl( writers... );
    if ( current_exception != nullptr ) {
      return current_exception;
    }
    return next_exception;
  }

  template< typename... Writers >
  inline void
  join_writers( Writers& ...writers ) {
    auto exception = join_writers_impl( writers... );
    if ( exception != nullptr ) {
      std::rethrow_exception( exception );
    }
  }
} // namespace hive::plugins::sql_serializer
