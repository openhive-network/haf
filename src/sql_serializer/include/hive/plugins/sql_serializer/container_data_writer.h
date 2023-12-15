#pragma once

#include <hive/plugins/sql_serializer/block_num_rendezvous_trigger.hpp>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>
#include <hive/plugins/sql_serializer/tables_descriptions.h>


#include <fc/exception/exception.hpp>

#include <type_traits>

namespace pqxx {
  namespace {
    // these helper functions are copied straight from pqxx, which marked them as "internal"
    inline constexpr std::size_t size_esc_bin(std::size_t binary_bytes) noexcept
    {
      return 2 + (2 * binary_bytes) + 1;
    }
    constexpr char hex_digits[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};

    // Translate a number (must be between 0 and 16 exclusive) to a hex digit.
    constexpr char hex_digit(int c) noexcept
    {
      return hex_digits[c];
    }
    // Translate a hex digit to a nibble.  Return -1 if it's not a valid digit.
    constexpr int nibble(int c) noexcept
    {
      if (c >= '0' && c <= '9')
        [[likely]] return c - '0';
      else if (c >= 'a' && c <= 'f')
        return 10 + (c - 'a');
      else if (c >= 'A' && c <= 'F')
        return 10 + (c - 'A');
      else
        return -1;
    }

    void esc_bin(std::basic_string_view<std::byte> binary_data, char buffer[]) noexcept
    {
      auto here{buffer};
      *here++ = '\\';
      *here++ = 'x';

      for (auto const byte : binary_data)
      {
        auto uc{static_cast<unsigned char>(byte)};
        *here++ = hex_digit(uc >> 4);
        *here++ = hex_digit(uc & 0x0f);
      }

      *here = '\0';
    }
    inline constexpr std::size_t size_unesc_bin(std::size_t escaped_bytes) noexcept
    {
      return (escaped_bytes - 2) / 2;
    }
    void unesc_bin(std::string_view escaped_data, std::byte buffer[])
    {
      auto const in_size{std::size(escaped_data)};
      if (in_size < 2)
        throw pqxx::failure{"Binary data appears truncated."};
      if ((in_size % 2) != 0)
        throw pqxx::failure{"Invalid escaped binary length."};
      char const* in{escaped_data.data()};
      char const* const end{in + in_size};
      if (*in++ != '\\' || *in++ != 'x')
        throw pqxx::failure("Escaped binary data did not start with '\\x'`.  Is the server or libpq "
                            "too old?");
      auto out{buffer};
      while (in != end)
      {
        int hi{nibble(*in++)};
        if (hi < 0)
          throw pqxx::failure{"Invalid hex-escaped data."};
        int lo{nibble(*in++)};
        if (lo < 0)
          throw pqxx::failure{"Invalid hex-escaped data."};
        *out++ = static_cast<std::byte>((hi << 4) | lo);
      }
    }
  } // end anonymous namespace for helper functions

// support for fc::optional<>, adapted from pqxx's existing support for std::optional
template <typename T> struct nullness<fc::optional<T>>
{
  static constexpr bool has_null = true;
  static constexpr bool always_null = nullness<T>::always_null;
  static constexpr bool is_null(fc::optional<T> const& v) noexcept { return ((!v.valid()) || pqxx::is_null(*v)); }
  static constexpr fc::optional<T> null() { return {}; }
};

template <typename T> inline constexpr format param_format(fc::optional<T> const& value) { return param_format(*value); }

template <typename T> struct string_traits<fc::optional<T>>
{
  static constexpr bool converts_to_string{string_traits<T>::converts_to_string};
  static constexpr bool converts_from_string{string_traits<T>::converts_from_string};

  static char* into_buf(char* begin, char* end, fc::optional<T> const& value) { return string_traits<T>::into_buf(begin, end, *value); }

  static zview to_buf(char* begin, char* end, fc::optional<T> const& value)
  {
    if (value.valid())
      return string_traits<T>::to_buf(begin, end, *value);
    else
      return {};
  }

  static fc::optional<T> from_string(std::string_view text) { return fc::optional<T>{std::in_place, string_traits<T>::from_string(text)}; }

  static std::size_t size_buffer(fc::optional<T> const& value) noexcept { return pqxx::size_buffer(value.value()); }
};

// ripemd160 to BYTEA, (for block hashes)
template<> std::string const type_name<fc::ripemd160>{"fc::ripemd160"};
template<> struct nullness<fc::ripemd160> : pqxx::no_null<fc::ripemd160> {};

template<> struct string_traits<fc::ripemd160>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};

  static zview to_buf(char *begin, char *end, const fc::ripemd160& value)
  {
    // we can't optimize this any more, just call into_buf()
    return generic_to_buf(begin, end, value);
  }

  static char *into_buf(char *begin, char *end, const fc::ripemd160& value)
  {
    if (end - begin < (long)size_buffer(value))
      throw conversion_overrun{"Could not write fc::ripemd160: buffer too small."};
    esc_bin(binary_cast(value.data(), value.data_size()), begin);
    return begin + size_buffer(value);
  }

  static constexpr std::size_t size_buffer(const fc::ripemd160&) noexcept { return size_esc_bin(sizeof(fc::ripemd160)); }

  static fc::ripemd160 from_string(std::string_view text)
  {
    fc::ripemd160 result;
    unesc_bin(text, reinterpret_cast<std::byte*>(result.data()));
    return result;
  }
};


// signatures to BYTEA
template<> std::string const type_name<fc::ecc::compact_signature>{"fc::ecc::compact_signature"};
template<> struct nullness<fc::ecc::compact_signature> : pqxx::no_null<fc::ecc::compact_signature> {};

template<> struct string_traits<fc::ecc::compact_signature>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};

  static zview to_buf(char *begin, char *end, const fc::ecc::compact_signature& value)
  {
    // we can't optimize this any more, just call into_buf()
    return generic_to_buf(begin, end, value);
  }

  static char *into_buf(char *begin, char *end, const fc::ecc::compact_signature& value)
  {
    if (end - begin < (long)size_buffer(value))
      throw conversion_overrun{"Could not write fc::ecc::compact_signature: buffer too small."};
    esc_bin(binary_cast(value.begin(), value.size()), begin);
    return begin + size_buffer(value);
  }

  static constexpr std::size_t size_buffer(const fc::ecc::compact_signature&) noexcept { return size_esc_bin(sizeof(fc::ecc::compact_signature)); }

  static fc::ecc::compact_signature from_string(std::string_view text)
  {
    fc::ecc::compact_signature result;
    unesc_bin(text, reinterpret_cast<std::byte*>(result.begin()));
    return result;
  }
};

// conversion for time_point_sec into an ISO8601 string like "2023-12-13T17:26:12" for
// PostgreSQL.
// *NOTE* right now this doesn't add a trailing "Z" because the haf database
// incorrectly uses "timestamp without time zone" everywhere.  if that is fixed,
// this converter will need to be updated to add a "Z" at the end.
template<> std::string const type_name<fc::time_point_sec>{"fc::time_point_sec"};
template<> struct nullness<fc::time_point_sec> : pqxx::no_null<fc::time_point_sec> {};

template<> struct string_traits<fc::time_point_sec>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};

private:
  static constexpr std::tuple<uint32_t, unsigned, unsigned, unsigned, unsigned, unsigned> to_ymd_hms(uint32_t seconds_since_epoch) noexcept
  {
    uint32_t z = seconds_since_epoch / 86400;

    z += 719468;
    const uint32_t era = z / 146097;
    const unsigned doe = static_cast<unsigned>(z - era * 146097);          // [0, 146096]
    const unsigned yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365;  // [0, 399]
    const uint32_t y = static_cast<uint32_t>(yoe) + era * 400;
    const unsigned doy = doe - (365*yoe + yoe/4 - yoe/100);                // [0, 365]
    const unsigned mp = (5*doy + 2)/153;                                   // [0, 11]
    const unsigned d = doy - (153*mp+2)/5 + 1;                             // [1, 31]
    const unsigned m = mp + (mp < 10 ? 3 : -9);                            // [1, 12]

    const uint32_t seconds_since_day = seconds_since_epoch % 86400;
    const uint32_t hours = seconds_since_day / 3600;
    const uint32_t seconds_since_hour = seconds_since_day % 3600;
    const uint32_t minutes = seconds_since_hour / 60;
    const uint32_t seconds = seconds_since_hour % 60;

    return std::make_tuple(y + (m <= 2), m, d, hours, minutes, seconds);
  }

  static constexpr void write_two_digits(char* s, uint32_t n)
  {
    const char* const digits = "00010203040506070809"
                               "10111213141516171819"
                               "20212223242526272829"
                               "30313233343536373839"
                               "40414243444546474849"
                               "50515253545556575859"
                               "60616263646566676869"
                               "70717273747576777879"
                               "80818283848586878889"
                               "90919293949596979899" + 2 * n;
    s[0] = digits[0];
    s[1] = digits[1];
  }
public:

  static zview to_buf(char *begin, char *end, const fc::time_point_sec& value)
  {
    // we can't optimize this any more, just call into_buf()
    return generic_to_buf(begin, end, value);
  }

  static char *into_buf(char *begin, char *end, const fc::time_point_sec& value)
  {
    if (end - begin < 20)
      throw conversion_overrun{"Could not write fc::time_point_sec: buffer too small."};
    const auto [year, month, day, hour, minute, second] = to_ymd_hms(value.sec_since_epoch());

    write_two_digits(begin, year / 100);
    write_two_digits(begin + 2, year % 100);
    begin[4] = '-';
    write_two_digits(begin + 5, month);
    begin[7] = '-';
    write_two_digits(begin + 8, day);
    begin[10] = 'T';
    write_two_digits(begin + 11, hour);
    begin[13] = ':';
    write_two_digits(begin + 14, minute);
    begin[16] = ':';
    write_two_digits(begin + 17, second);
    begin[19] = 0;
    return begin + 20;
  }

  // we don't have to deal with years > 9999
  static constexpr std::size_t size_buffer(const fc::time_point_sec &) noexcept { return 20; }

  static fc::time_point_sec from_string(std::string_view text)
  {
    // note: not particularly fast, but haf doesn't currently use this at all
    return fc::time_point_sec::from_iso_string(std::string(text));
  }
};

// operation to BYTEA (the code would be about the same for any binary serialized object)
template<> std::string const type_name<hive::protocol::operation>{"hive::protocol::operation"};
template<> struct nullness<hive::protocol::operation> : pqxx::no_null<hive::protocol::operation> {};
template<> struct string_traits<hive::protocol::operation>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};
  
  static zview to_buf(char *begin, char *end, const fc::time_point_sec& value)
  {
    // we can't optimize this any more, just call into_buf()
    return generic_to_buf(begin, end, value);
  }
  
  static char *into_buf(char *begin, char *end, const hive::protocol::operation& value)
  {
    fc::datastream<char*> datastream(begin, end - begin);
    try
    {
      fc::raw::pack(datastream, value);
    }
    catch (const fc::out_of_range_exception&)
    {
      throw conversion_overrun{"Could not write hive::protocol::operation: buffer too small."};
    }
    
    // we know that serializing an operation will never lead to 0 bytes.
    const size_t raw_size = datastream.tellp();
    
    if (end - begin < (long)size_buffer(value))
      throw conversion_overrun{"Could not write hive::protocol::operation: buffer too small."};
    
    // so at this point, we have a buffer with the binary data at the beginning
    // and then a bunch of uninitialized data after it.
    // now hex-encode the string, working backwards from the end
    char* end_of_data = begin + raw_size * 2 + 3;
    char* null_terminator = end_of_data - 1;
    *null_terminator = 0;
    
    // start raw_pointer pointing at the last byte of raw data
    char* raw_pointer = begin + raw_size - 1;
    // and the cooked_pointer at the destination of the last hex char
    char* cooked_pointer = null_terminator - 1;
    
    for (size_t i = 0; i < raw_size; ++i)
    {
      unsigned char as_unsigned = *raw_pointer--;
      *cooked_pointer-- = hex_digit(as_unsigned & 0x0f);
      *cooked_pointer-- = hex_digit(as_unsigned >> 4);
    }

    // we should now have everything encoded, and just need to add the \x
    *raw_pointer-- = 'x';
    *raw_pointer-- = '\\';
    
    return end_of_data;
  }
  
  static std::size_t size_buffer(const hive::protocol::operation& value)
  {
    fc::datastream<size_t> size_packer;
    fc::raw::pack(size_packer, value);
    return size_esc_bin(size_packer.tellp());
  }

  static hive::protocol::operation from_string(std::string_view text)
  {
    // TODO: dehexify `text`, this probably won't work as is
    fc::datastream<const char*> datastream(text.data(), text.size());
    hive::protocol::operation op;
    fc::raw::unpack(datastream, op);
    return op;
  }
};

} // end namespace pqxx

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
      pqxx::stream_to stream = pqxx::stream_to::raw_table(work, TABLE_NAME, COLUMN_LIST);
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
