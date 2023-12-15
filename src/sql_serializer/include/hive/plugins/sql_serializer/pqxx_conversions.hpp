#pragma once

#include <hive/protocol/config.hpp>
#include <type_traits>
#include <fc/crypto/ripemd160.hpp>

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

// +--------------+
// | fc::optional |
// +--------------+
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

// +---------------+
// | fc::ripemd160 |
// +---------------+
// ripemd160 to BYTEA, (for block hashes)
template<> std::string const type_name<fc::ripemd160>{"fc::ripemd160"};
template<> struct nullness<fc::ripemd160> : pqxx::no_null<fc::ripemd160> {};

template<> struct string_traits<fc::ripemd160>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};

  static zview to_buf(char *begin, char *end, const fc::ripemd160& value)
  {
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


// +----------------------------+
// | fc::ecc::compact_signature |
// +----------------------------+
// signatures to BYTEA
template<> std::string const type_name<fc::ecc::compact_signature>{"fc::ecc::compact_signature"};
template<> struct nullness<fc::ecc::compact_signature> : pqxx::no_null<fc::ecc::compact_signature> {};

template<> struct string_traits<fc::ecc::compact_signature>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};

  static zview to_buf(char *begin, char *end, const fc::ecc::compact_signature& value)
  {
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

// +-----------------------+
// | hive::protocol::asset |
// +-----------------------+
// Converts the `amount` part of an asset into a number, discards the symbol part
template<uint32_t SYMBOL> std::string const type_name<hive::protocol::tiny_asset<SYMBOL>>{"hive::protocol::tiny_asset<" + std::to_string(SYMBOL) +">"};
template<uint32_t SYMBOL> struct nullness<hive::protocol::tiny_asset<SYMBOL>> : pqxx::no_null<hive::protocol::tiny_asset<SYMBOL>> {};

template<uint32_t SYMBOL> struct string_traits<hive::protocol::tiny_asset<SYMBOL>>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};

  static zview to_buf(char *begin, char *end, const hive::protocol::tiny_asset<SYMBOL>& value)
  {
    return string_traits<int64_t>::to_buf(begin, end, value.amount.value);
  }

  static char *into_buf(char *begin, char *end, const hive::protocol::tiny_asset<SYMBOL>& value)
  {
    return string_traits<int64_t>::into_buf(begin, end, value.amount.value);
  }

  static constexpr std::size_t size_buffer(const hive::protocol::tiny_asset<SYMBOL>& value) noexcept
  {
    return string_traits<int64_t>::size_buffer(value.amount.value);
  }

  static hive::protocol::tiny_asset<SYMBOL> from_string(std::string_view text)
  {
    return hive::protocol::tiny_asset<SYMBOL>(string_traits<int64_t>::from_string(text));
  }
};

// +---------------------------------+
// | hive::protocol::public_key_type |
// +---------------------------------+
// converts public_key to TEXT (why not BYTEA?)
template<> std::string const type_name<hive::protocol::public_key_type>{"hive::protocol::public_key_type"};
template<> struct nullness<hive::protocol::public_key_type> : pqxx::no_null<hive::protocol::public_key_type> {};

template<> struct string_traits<hive::protocol::public_key_type>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};
private:
  // base58 algorithm adapted from https://github.com/martinus/base58 (MIT license)
  static char* encode(void const* const input_data, size_t input_size, char* out)
  {
    // Skip & count leading zeroes. Zeroes are discarded
    auto const* input = static_cast<uint8_t const*>(input_data);
    auto const* const input_end = input + input_size;
    while (input != input_end && *input == 0)
      ++input;
    auto const skipped_leading_zeroes_size = static_cast<size_t>(input - static_cast<uint8_t const*>(input_data));
    // original code dealt with leading zeros like this:
    // *out++ = '1';
    // but it seems fc's implementation omits them.  more testing needed if this code is used outside of 
    // public keys
    input_size -= skipped_leading_zeroes_size;

    // Allocate enough space for base58 representation.
    //
    // ln(256)/ln(58) = 1.365 symbols of b58 are required per input byte. Instead of floating point operations we can approximate
    // this by a multiplication and division, e.g. by * 1365 / 1000. This is faster and has no floating point ambiguity. Note that
    // multiplier and divisor should be kept relatively small so we don't risk an overflow with input_size.
    //
    // Even better, we can choose a divisor that is a power of two so we can replace the division with a shift, which is even
    // faster: ln(256)/ln(58) * 2^8 = 349.6. To be on the safe side we round up and add 1.
    //
    // For 32bit size_t this will overflow at (2^32255)/350 + 1 = 12271336. So you can't encode more than ~12 MB. But who would do
    // that anyways?
    auto const expected_encoded_size = ((input_size * 350U) >> 8U) + 1U;

    auto* const b58_end = out + expected_encoded_size;

    // Initially the b58 number is empty, it grows in each loop.
    auto* b58_begin_minus1 = b58_end - 1;

    // The conversion algorithm works by repeatedly calculating
    //
    //     b58 = b58 * 256 + inputbyte
    //
    // until all input bytes have been processed. Both the input bytes and b58 bytes are in big endian format, so leftmost byte is
    // most significant byte (MSB) and rightmost the least significant byte (LSB). Each b58*256 + inputbyte operation is done by
    // iterating from LSB to MSB of b58 while multiplying each digit, adding inputbytes, and outputting the remainder of result
    // % 58. The remainder is carried over to the next b58 digit.
    //
    // That way we do not need bignum support and can work with arbitrarily large numbers, with a runtime complexity of O(n^2).
    //
    // This loop can be easily extended to process multiple bytes at once: To process 7 input bytes, we can instead calculate
    //
    //     b58 = b58 * 256^7 + inputbytes
    //
    // The algorithm is still O(n^2), but lot less multiplications have to be performed. How many numbers can we ideally choose
    // for maximum performance? 7 bytes. That way we can operate on 64 bit words without risking an overflow. For the worst case
    // of having only 0xFF as input bytes, and already 57 = 0x39 stored in b58, the maximum size for the carryover is
    //
    //     max_carry = 0x39 * 0x0100'0000'0000'0000 + 0x00FF'FFFF'FFFF'FFFF
    //     max_carry = 0x39FF'FFFF'FFFF'FFFF.
    //
    // Given max_carry of 0x39FF'FFFF'FFFF'FFFF we output carry % 58 = 58, and continue with a carry of carry=carry/58 =
    // 0x00FF'FFFF'FFFF'FFFF. We are at the same carry value as before, so no overflow happening here.

    // Since the algorithm complexity is quadratic and runtime increases as b58 gets larger, it is faster to do the remainder
    // first so that the intermediate numbers are kept smaller. For example, when processing 15 input bytes, we split them into 15
    // = 1+7+7 bytes instead of 7+7+1.
    size_t num_bytes_to_process = ((input_size - 1U) % 7U) + 1U;

    // Process the bytes.
    while (input != input_end)
    {
      // take num_bytes_to_process input bytes and store them into carry.
      auto carry = uint64_t();
      for (auto num_bytes = size_t(); num_bytes < num_bytes_to_process; ++num_bytes)
      {
        carry <<= 8U;
        carry += *input++;
      }
      auto const multiplier = uint64_t(1) << (num_bytes_to_process * 8U);

      // for all remaining input data we process 7 bytes at once.
      num_bytes_to_process = 7U;

      // Apply "b58 = b58 * multiplier + carry". Process until all b58 digits have been processed, then finish until carry is 0.
      auto* it = b58_end - 1U;

      // process all digits from b58
      while (it > b58_begin_minus1)
      {
        carry += multiplier * static_cast<uint8_t>(*it);
        *it-- = static_cast<char>(carry % 58U);
        carry /= 58;
      }

      // finish with the carry. At most this will be executed ln(0x39FF'FFFF'FFFF'FFFF) / ln(58) = 10.6 = 11 times.
      // Unrolling this loop manually seems to help performance in my benchmarks
      while (carry > 58 * 58)
      {
        *it-- = static_cast<char>(carry % 58U);
        carry /= 58;
        *it-- = static_cast<char>(carry % 58U);
        carry /= 58;
        *it-- = static_cast<char>(carry % 58U);
        carry /= 58;
      }
      while (carry != 0)
      {
        *it-- = static_cast<char>(carry % 58U);
        carry /= 58;
      }
      b58_begin_minus1 = it;
    }

    // Now b58_begin_minus1 + 1 to b58_end stores the whole number in base 58. Finally translate this number into a string based
    // on the alphabet.
    auto it = b58_begin_minus1 + 1;
    auto* b58_text_it = out;
    while (it < b58_end)
    {
      *b58_text_it++ = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"[static_cast<uint8_t>(*it++)];
    }

    // null terminate
    *b58_text_it++ = 0;

    // return the byte after the null terminator
    return b58_text_it;
  }

  static constexpr auto charToBase58 = std::array<uint8_t, 123>{{
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0,
      1,   2,   3,   4,   5,   6,   7,   8,   255, 255, 255, 255, 255, 255, 255, 9,   10,  11,  12,  13,  14,  15,  16,  255, 17,
      18,  19,  20,  21,  255, 22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  32,  255, 255, 255, 255, 255, 255, 33,  34,  35,
      36,  37,  38,  39,  40,  41,  42,  43,  255, 44,  45,  46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,
  }};

  static constexpr auto multipliers = std::array<uint64_t, 9>{{
      uint64_t(58),
      uint64_t(58) * 58U,
      uint64_t(58) * 58U * 58U,
      uint64_t(58) * 58U * 58U * 58U,
      uint64_t(58) * 58U * 58U * 58U * 58U * 58U,
      uint64_t(58) * 58U * 58U * 58U * 58U * 58U * 58U,
      uint64_t(58) * 58U * 58U * 58U * 58U * 58U * 58U * 58U,
      uint64_t(58) * 58U * 58U * 58U * 58U * 58U * 58U * 58U * 58U,
      uint64_t(58) * 58U * 58U * 58U * 58U * 58U * 58U * 58U * 58U * 58U,
  }};
public:

  static zview to_buf(char *begin, char *end, const hive::protocol::public_key_type& value)
  {
    return generic_to_buf(begin, end, value);
  }

  static char *into_buf(char *begin, char *end, const hive::protocol::public_key_type& value)
  {
    if (end - begin < (long)size_buffer(value))
      throw conversion_overrun{"Could not write hive::protocol::public_key_type: buffer too small."};

    // public_key_data is 33 bytes
    const fc::ecc::public_key_data key_data{value};
    uint32_t check = (uint32_t)fc::ripemd160::hash(key_data.data, sizeof(key_data))._hash[0];
    // combine into a single buffer
    constexpr size_t raw_size = sizeof(key_data) + sizeof(check);
    char data_to_encode[raw_size];
    memcpy(data_to_encode, key_data.begin(), key_data.size());
    memcpy(data_to_encode + key_data.size(), (const char*)&check, sizeof(check));

    // write the prefix to our output buffer
    constexpr size_t prefix_length = std::string_view(HIVE_ADDRESS_PREFIX).size();
    memcpy(begin, HIVE_ADDRESS_PREFIX, prefix_length);

    // write the base58 data after it
    return encode(data_to_encode, raw_size, begin + prefix_length);
  }

  static constexpr std::size_t size_buffer(const hive::protocol::public_key_type&) noexcept {
    // pubkey looks like "STM" + base58 stuff.  The base58 portion is the encoded
    // version of 37 bytes (33 bytes of data + 4 bytes checksum).
    // The base58 portion will encode to 50 bytes, but the algorithm above computes
    // expected_encoded_size = 51 bytes so we give it the extra byte.
    // to that, add a prefix (usually 3 chars "STM") and a null terminator
    return 51 + std::string_view(HIVE_ADDRESS_PREFIX).size() + 1;
  }

  static hive::protocol::public_key_type from_string(std::string_view text)
  {
    // unused, untested, un-optimized
    return hive::protocol::public_key_type(std::string(text));
  }
};


// +--------------------+
// | fc::time_point_sec |
// +--------------------+
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

// +---------------------------+
// | hive::protocol::operation |
// +---------------------------+
// operation to BYTEA (this code could be generalized, should be about the same for any 
// would be about the same for any binary serialized object)
template<> std::string const type_name<hive::protocol::operation>{"hive::protocol::operation"};
template<> struct nullness<hive::protocol::operation> : pqxx::no_null<hive::protocol::operation> {};
template<> struct string_traits<hive::protocol::operation>
{
  static constexpr bool converts_to_string{true};
  static constexpr bool converts_from_string{true};
  
  static zview to_buf(char *begin, char *end, const hive::protocol::operation& value)
  {
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
    *cooked_pointer-- = 'x';
    *cooked_pointer-- = '\\';
    
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
    // totally untested
    const size_t binary_size = size_unesc_bin(text.size());
    std::unique_ptr<std::byte[]> buffer{new std::byte[binary_size]};
    unesc_bin(text, buffer.get());
    fc::datastream<const char*> datastream((const char*)buffer.get(), binary_size);
    hive::protocol::operation op;
    fc::raw::unpack(datastream, op);
    return op;
  }
};

} // end namespace pqxx

