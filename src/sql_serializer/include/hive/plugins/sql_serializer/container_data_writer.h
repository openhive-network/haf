#pragma once

#include <hive/plugins/sql_serializer/block_num_rendezvous_trigger.hpp>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>
#include <hive/plugins/sql_serializer/tables_descriptions.h>


#include <fc/exception/exception.hpp>

#include <type_traits>

namespace pqxx {
  namespace {
    std::string escape_binary(std::string_view binary_str)
    { 
      std::string result;
      result.resize(binary_str.size() * 2 + 2);
      unsigned pos = 0;
      result[pos++] = '\\';
      result[pos++] = 'x';
      constexpr const char* to_hex = "0123456789abcdef";
      for (const char c : binary_str)
      {
        result[pos++] = to_hex[(unsigned char)c >> 4];
        result[pos++] = to_hex[(unsigned char)c & 0x0f];
      }
      return result;
    }
  }
  template<> struct string_traits<binarystring>
  {
    static constexpr const char *name() noexcept { return "binarystring"; }
    static constexpr bool has_null() noexcept { return false; }
    static bool is_null(const binarystring&) { return false; }
    [[noreturn]] static binarystring null() { internal::throw_null_conversion(name()); }
    static void from_string(const char Str[], binarystring &Obj) { FC_ASSERT(false, "not implemented"); }
    static std::string to_string(const binarystring& binary_str) { return escape_binary(std::string_view((const char*)binary_str.data(), binary_str.size())); }
  };
  template<> struct string_traits<fc::time_point_sec>
  {
    static constexpr const char *name() noexcept { return "fc::time_point_sec"; }
    static constexpr bool has_null() noexcept { return false; }
    static bool is_null(const fc::time_point_sec&) { return false; }
    [[noreturn]] static fc::time_point_sec null() { internal::throw_null_conversion(name()); }
    static void from_string(const char Str[], fc::time_point_sec &Obj) { FC_ASSERT(false, "not implemented"); }
    static std::string to_string(const fc::time_point_sec& time_point) { return time_point.to_iso_string(); }
  };
  template<> struct string_traits<fc::ripemd160>
  {
    static constexpr const char *name() noexcept { return "fc::ripemd160"; }
    static constexpr bool has_null() noexcept { return false; }
    static bool is_null(const fc::ripemd160&) { return false; }
    [[noreturn]] static fc::ripemd160 null() { internal::throw_null_conversion(name()); }
    static void from_string(const char Str[], fc::ripemd160 &Obj) { FC_ASSERT(false, "not implemented"); }
    static std::string to_string(const fc::ripemd160& hash) { return escape_binary(std::string_view(hash.data(), hash.data_size())); }
  };
  template<> struct string_traits<fc::ecc::compact_signature>
  {
    static constexpr const char *name() noexcept { return "fc::ecc::compact_signature"; }
    static constexpr bool has_null() noexcept { return false; }
    static bool is_null(const fc::ecc::compact_signature&) { return false; }
    [[noreturn]] static fc::ecc::compact_signature null() { internal::throw_null_conversion(name()); }
    static void from_string(const char Str[], fc::ecc::compact_signature &Obj) { FC_ASSERT(false, "not implemented"); }
    static std::string to_string(const fc::ecc::compact_signature& sig) { return escape_binary(std::string_view((const char*)sig.begin(), sig.size())); }
  };
}

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
  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, const char* const COLS_ARRAY[], int COLS_ARRAY_LEN, typename Processor = queries_commit_data_processor >
    class container_data_writer
      {
      public:
        using DataContainerType = DataContainer;
        using DataProcessor = Processor;

        container_data_writer(
            std::string psqlUrl
          , std::string description
          , std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger
          , appbase::application& app
        ) {
          _processor = std::make_unique<Processor>(psqlUrl, description, flush_replayed_data, _randezvous_trigger, app);
        }

        container_data_writer(
            std::function< void(std::string&&) > string_callback
          , std::string description
          , std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger
          , appbase::application& app
        ) {
          _processor = std::make_unique<Processor>(string_callback, description, flush_scalar_live_data, _randezvous_trigger, app);
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

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, const char* const COLUMN_ARRAY[], int COLUMN_ARRAY_LEN, typename Processor>
  inline void
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, COLUMN_ARRAY, COLUMN_ARRAY_LEN, Processor >::trigger(DataContainer&& data, uint32_t last_block_num)
  {
    if(data.empty() == false)
    {
      _processor->trigger(std::make_unique<chunk>(std::move(data)), last_block_num);
    } else {
      _processor->only_report_batch_finished( last_block_num );
    }

    FC_ASSERT(data.empty(), "DATA empty 1");
  }

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, const char* const COLUMN_ARRAY[], int COLUMN_ARRAY_LEN, typename Processor>
  inline void
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, COLUMN_ARRAY, COLUMN_ARRAY_LEN, Processor >::complete_data_processing()
  {
    _processor->complete_data_processing();
  }

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, const char* const COLUMN_ARRAY[], int COLUMN_ARRAY_LEN, typename Processor>
  inline void
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, COLUMN_ARRAY, COLUMN_ARRAY_LEN, Processor >::join()
  {
    _processor->join();
  }

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, const char* const COLUMN_ARRAY[], int COLUMN_ARRAY_LEN, typename Processor>
  inline typename container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, COLUMN_ARRAY, COLUMN_ARRAY_LEN, Processor >::data_processing_status
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, COLUMN_ARRAY, COLUMN_ARRAY_LEN, Processor >::flush_replayed_data(const data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx)
  {
    const chunk* holder = static_cast<const chunk*>(dataPtr.get());
    data_processing_status processingStatus;

    const DataContainer& data = holder->_data;
    FC_ASSERT(!data.empty(), "Data empty 2");

    tx.run_in_transaction([&](pqxx::work& work) {
      pqxx::stream_to stream{work, TABLE_NAME, std::vector<std::string>{COLUMN_ARRAY, COLUMN_ARRAY + COLUMN_ARRAY_LEN}};
      for (auto i = data.cbegin(); i != data.cend(); ++i) 
        stream << to_tuple(*i);
      stream.complete();
    });

    processingStatus.first += data.size();
    processingStatus.second = true;

    return processingStatus;
  }

  template <class DataContainer, class TupleConverter, const char* const TABLE_NAME, const char* const COLUMN_LIST, const char* const COLUMN_ARRAY[], int COLUMN_ARRAY_LEN, typename Processor>
  inline typename container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, COLUMN_ARRAY, COLUMN_ARRAY_LEN, Processor >::data_processing_status
  container_data_writer<DataContainer, TupleConverter, TABLE_NAME, COLUMN_LIST, COLUMN_ARRAY, COLUMN_ARRAY_LEN, Processor >::flush_scalar_live_data(const data_chunk_ptr& dataPtr, std::function< void(std::string&&) > callback)
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
