#include "l2_jcs.hpp"

#include <fc/variant.hpp>
#include <fc/variant_object.hpp>
#include <fc/exception/exception.hpp>

#include <algorithm>
#include <vector>
#include <cstdint>

namespace l2
{
namespace
{
  // 2^53 - 1, the largest integer JSON's IEEE-754 number model represents exactly.
  const int64_t JCS_MAX_SAFE_INT =  9007199254740991LL;
  const int64_t JCS_MIN_SAFE_INT = -9007199254740991LL;

  // Decode a UTF-8 string into its UTF-16 code-unit sequence (for RFC-8785 key
  // ordering, which compares by UTF-16 code unit). Input is assumed valid UTF-8
  // (it comes from a parsed JSONB value).
  std::vector<uint16_t> utf8_to_utf16( const std::string& s )
  {
    std::vector<uint16_t> out;
    out.reserve( s.size() );
    size_t i = 0;
    const size_t n = s.size();
    while( i < n )
    {
      const unsigned char c = static_cast<unsigned char>( s[i] );
      uint32_t cp = 0;
      int len = 1;
      if( c < 0x80 )            { cp = c;          len = 1; }
      else if( ( c >> 5 ) == 0x6 ) { cp = c & 0x1F; len = 2; }
      else if( ( c >> 4 ) == 0xE ) { cp = c & 0x0F; len = 3; }
      else                      { cp = c & 0x07; len = 4; }
      for( int k = 1; k < len && i + k < n; ++k )
        cp = ( cp << 6 ) | ( static_cast<unsigned char>( s[i + k] ) & 0x3F );
      i += len;

      if( cp <= 0xFFFF )
        out.push_back( static_cast<uint16_t>( cp ) );
      else
      {
        cp -= 0x10000;
        out.push_back( static_cast<uint16_t>( 0xD800 + ( cp >> 10 ) ) );
        out.push_back( static_cast<uint16_t>( 0xDC00 + ( cp & 0x3FF ) ) );
      }
    }
    return out;
  }

  // RFC-8785 string serialization: minimal escaping (per ECMAScript JSON.stringify),
  // everything else emitted as raw UTF-8 bytes.
  void append_json_string( std::string& out, const std::string& s )
  {
    static const char* HEX = "0123456789abcdef";
    out.push_back( '"' );
    for( size_t i = 0; i < s.size(); ++i )
    {
      const unsigned char c = static_cast<unsigned char>( s[i] );
      switch( c )
      {
        case '"':  out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\b': out += "\\b";  break;
        case '\f': out += "\\f";  break;
        case '\n': out += "\\n";  break;
        case '\r': out += "\\r";  break;
        case '\t': out += "\\t";  break;
        default:
          if( c < 0x20 )
          {
            out += "\\u00";
            out.push_back( HEX[( c >> 4 ) & 0xF] );
            out.push_back( HEX[c & 0xF] );
          }
          else
            out.push_back( static_cast<char>( c ) );  // raw UTF-8 byte
      }
    }
    out.push_back( '"' );
  }
} // anonymous namespace

void jcs_canonicalize( const fc::variant& v, std::string& out )
{
  switch( v.get_type() )
  {
    case fc::variant::null_type:
      out += "null";
      break;

    case fc::variant::bool_type:
      out += v.as_bool() ? "true" : "false";
      break;

    case fc::variant::int64_type:
    {
      const int64_t i = v.as_int64();
      FC_ASSERT( i >= JCS_MIN_SAFE_INT && i <= JCS_MAX_SAFE_INT,
        "L2 JCS: integer ${i} is outside the safe range +-(2^53-1); carry large values as strings", ("i", i) );
      out += std::to_string( i );
      break;
    }

    case fc::variant::uint64_type:
    {
      const uint64_t u = v.as_uint64();
      FC_ASSERT( u <= static_cast<uint64_t>( JCS_MAX_SAFE_INT ),
        "L2 JCS: integer ${u} is outside the safe range +-(2^53-1); carry large values as strings", ("u", u) );
      out += std::to_string( u );
      break;
    }

    case fc::variant::double_type:
      FC_ASSERT( false,
        "L2 JCS: floating-point numbers are not allowed in signed L2 transaction bodies; carry decimals as strings" );
      break;

    case fc::variant::string_type:
    {
      const std::string s = v.as_string();
      append_json_string( out, s );
      break;
    }

    case fc::variant::array_type:
    {
      const fc::variants& arr = v.get_array();
      out.push_back( '[' );
      for( size_t i = 0; i < arr.size(); ++i )
      {
        if( i ) out.push_back( ',' );
        jcs_canonicalize( arr[i], out );
      }
      out.push_back( ']' );
      break;
    }

    case fc::variant::object_type:
    {
      const fc::variant_object& obj = v.get_object();
      std::vector<const fc::variant_object::entry*> entries;
      for( auto it = obj.begin(); it != obj.end(); ++it )
        entries.push_back( &*it );

      std::sort( entries.begin(), entries.end(),
        []( const fc::variant_object::entry* a, const fc::variant_object::entry* b )
        {
          return utf8_to_utf16( a->key() ) < utf8_to_utf16( b->key() );
        } );

      out.push_back( '{' );
      for( size_t i = 0; i < entries.size(); ++i )
      {
        if( i ) out.push_back( ',' );
        append_json_string( out, entries[i]->key() );
        out.push_back( ':' );
        jcs_canonicalize( entries[i]->value(), out );
      }
      out.push_back( '}' );
      break;
    }

    default:
      FC_ASSERT( false, "L2 JCS: unsupported JSON value type ${t}", ("t", static_cast<int>( v.get_type() )) );
  }
}

} // namespace l2
