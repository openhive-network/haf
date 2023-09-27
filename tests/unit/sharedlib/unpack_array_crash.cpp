#include <boost/test/unit_test.hpp>

#include <hive/protocol/operations.hpp>

#include <fc/io/raw.hpp>


namespace my {
  struct account_create_operation : public hive::protocol::base_operation
  {
    // hive::protocol::asset             fee;
    // hive::protocol::account_name_type creator;
    // hive::protocol::account_name_type new_account_name;
    // hive::protocol::authority         owner;
    // hive::protocol::authority         active;
    // hive::protocol::authority         posting;
    hive::protocol::public_key_type   memo_key;
    hive::protocol::json_string       json_metadata;
  };

  typedef fc::static_variant<
    hive::protocol::vote_operation, // 0
    hive::protocol::comment_operation, // 1
    hive::protocol::transfer_operation, // 2
    hive::protocol::transfer_to_vesting_operation, // 3
    hive::protocol::withdraw_vesting_operation, // 4
    // hive::protocol::limit_order_create_operation, // 5
    // hive::protocol::limit_order_cancel_operation, // 6
    // hive::protocol::feed_publish_operation, // 7
    // hive::protocol::convert_operation, // 8
    account_create_operation  // 9
  > operation;

    template<typename T>
    T __attribute__ ((noinline)) unpack_from_char_array( const char* d, uint32_t s, uint32_t depth = 0 )
    {
    { try {
        depth++;
        T v = {};
        // std::string str(d, s);
        // std::stringstream ss(str);
        fc::datastream<const char*>  ds( d, s );
        fc::raw::unpack(ds,v,depth);
        return v;
    } FC_RETHROW_EXCEPTIONS( warn, "error unpacking {type}" ) }
    }

    template<typename T>
    void __attribute__ ((noinline)) unpack_from_char_array( const char* d, uint32_t s, T& v, uint32_t depth = 0 )
    {
    { try {
        depth++;
        // std::string str(d, s);
        // std::stringstream ss(str);
        fc::datastream<const char*>  ds( d, s );
        fc::raw::unpack(ds,v,depth);
    } FC_RETHROW_EXCEPTIONS( warn, "error unpacking {type}" ) }
    }
}
FC_REFLECT( my::account_create_operation,
        // (fee)
        // (creator)
        // (new_account_name)
        // (owner)
        // (active)
        // (posting)
        (memo_key)
        (json_metadata)
        )


  BOOST_AUTO_TEST_CASE( unpack_array_nocrash )
  {
    std::string abc = ""; // to have the same situation like with crash test
    const char buffer[] = { char(0x09),char(0x10),char(0x27),char(0x00),char(0x00),char(0x00),char(0x00),char(0x00),char(0x00),char(0x03),char(0x53),char(0x54),char(0x45),char(0x45),char(0x4d),char(0x00),char(0x00),char(0x05),char(0x73),char(0x74),char(0x65),char(0x65),char(0x6d),char(0x07),char(0x6b),char(0x65),char(0x66),char(0x61),char(0x64),char(0x65),char(0x78),char(0x01),char(0x00),char(0x00),char(0x00),char(0x00),char(0x01),char(0x03),char(0xa7),char(0x88),char(0x88),char(0xf1),char(0xcd),char(0x1f),char(0x03),char(0x9e),char(0x63),char(0xef),char(0x93),char(0x31),char(0x4f),char(0xc1),char(0xfb),char(0x19),char(0x6c),char(0xc3),char(0x8d),char(0x5b),char(0x20),char(0x90),char(0xc8),char(0xdf),char(0x49),char(0xb8),char(0x06),char(0xee),char(0xda),char(0x4f),char(0x3e),char(0x35),char(0x01),char(0x00),char(0x01),char(0x00),char(0x00),char(0x00),char(0x00),char(0x01),char(0x03),char(0x1c),char(0x0e),char(0x33),char(0xa2),char(0x7b),char(0xce),char(0xc9),char(0x21),char(0xd6),char(0xa9),char(0xc3),char(0xca),char(0xf2),char(0xe1),char(0xce),char(0x40),char(0x52),char(0xd5),char(0x5b),char(0xcd),char(0x6a),char(0x68),char(0x43),char(0x72),char(0xe9),char(0x06),char(0x90),char(0xd9),char(0xc2),char(0x32),char(0xc9),char(0xc7),char(0x01),char(0x00),char(0x01),char(0x00),char(0x00),char(0x00),char(0x00),char(0x01),char(0x03),char(0x6d),char(0xa5),char(0xbc),char(0x9d),char(0xe6),char(0xff),char(0x21),char(0x10),char(0x75),char(0x1f),char(0x32),char(0xc1),char(0x91),char(0x97),char(0x04),char(0xa5),char(0x11),char(0x6a),char(0xde),char(0xee),char(0x0b),char(0x2b),char(0x7f),char(0x28),char(0xdf),char(0x24),char(0x4f),char(0xca),char(0x84),char(0x7b),char(0xa5),char(0x59),char(0x01),char(0x00),char(0x03),char(0xf7),char(0x48),char(0x79),char(0xa4),char(0x4d),char(0x3f),char(0xe2),char(0x15),char(0x23),char(0x20),char(0x98),char(0xbf),char(0x42),char(0x8d),char(0x64),char(0x12),char(0xff),char(0x22),char(0x05),char(0x13),char(0x13),char(0xe7),char(0x13),char(0x2d),char(0xf1),char(0xf0),char(0x6e),char(0xd8),char(0x40),char(0xaa),char(0xe8),char(0x1b),char(0x00)};
    try {
      auto result
        = fc::raw::unpack_from_char_array<hive::protocol::operation>( buffer, 188  );
    } catch( fc::exception& _e ) {
      BOOST_TEST_MESSAGE( _e.what() );
    }
  }

BOOST_AUTO_TEST_CASE( unpack_array_crash )
{
  std::string abc = ""; // wtf ?? this unused string is required to repeat the crash
  const char buffer[] = {
    char(0x05), // tag
    // hive::protocol::asset             fee
    // char(0x10),char(0x27),char(0x00),char(0x00),char(0x00),char(0x00),char(0x00),char(0x00), // share_type        amount
    // char(0x03),char(0x53),char(0x54),char(0x45),char(0x45),char(0x4d),char(0x00),char(0x00), // asset_symbol_type symbol
    // char(0x05),char(0x73),char(0x74),char(0x65),char(0x65),char(0x6d), // hive::protocol::account_name_type creator
    // char(0x07),char(0x6b),char(0x65),char(0x66),char(0x61),char(0x64),char(0x65),char(0x78), // hive::protocol::account_name_type new_account_name
    // hive::protocol::authority         owner
    // char(0x01),char(0x00),char(0x00),char(0x00), // uint32_t  weight_threshold
    // char(0x00), // account_authority_map  account_auths
    // char(0x01), // key_authority_map  key_auths
    // char(0x03),char(0xa7),char(0x88),char(0x88),char(0xf1),char(0xcd),char(0x1f),char(0x03),char(0x9e),char(0x63),char(0xef),char(0x93),char(0x31),char(0x4f),char(0xc1),char(0xfb),char(0x19),char(0x6c),char(0xc3),char(0x8d),char(0x5b),char(0x20),char(0x90),char(0xc8),char(0xdf),char(0x49),char(0xb8),char(0x06),char(0xee),char(0xda),char(0x4f),char(0x3e),char(0x35), // K
    // char(0x01),char(0x00), // V
    // hive::protocol::authority         active
    // char(0x01),char(0x00),char(0x00),char(0x00),
    // char(0x00),
    // char(0x01),
    // char(0x03),char(0x1c),char(0x0e),char(0x33),char(0xa2),char(0x7b),char(0xce),char(0xc9),char(0x21),char(0xd6),char(0xa9),char(0xc3),char(0xca),char(0xf2),char(0xe1),char(0xce),char(0x40),char(0x52),char(0xd5),char(0x5b),char(0xcd),char(0x6a),char(0x68),char(0x43),char(0x72),char(0xe9),char(0x06),char(0x90),char(0xd9),char(0xc2),char(0x32),char(0xc9),char(0xc7),
    // char(0x01),char(0x00),
    // hive::protocol::authority         posting
    // char(0x01),char(0x00),char(0x00),char(0x00),
    // char(0x00),
    // char(0x01),
    // char(0x03),char(0x6d),char(0xa5),char(0xbc),char(0x9d),char(0xe6),char(0xff),char(0x21),char(0x10),char(0x75),char(0x1f),char(0x32),char(0xc1),char(0x91),char(0x97),char(0x04),char(0xa5),char(0x11),char(0x6a),char(0xde),char(0xee),char(0x0b),char(0x2b),char(0x7f),char(0x28),char(0xdf),char(0x24),char(0x4f),char(0xca),char(0x84),char(0x7b),char(0xa5),char(0x59),
    // char(0x01),char(0x00),
    /// hive::protocol::public_key_type   memo_key
    char(0x03),char(0xf7),char(0x48),char(0x79),char(0xa4),char(0x4d),char(0x3f),char(0xe2),char(0x15),char(0x23),char(0x20),char(0x98),char(0xbf),char(0x42),char(0x8d),char(0x64),char(0x12),char(0xff),char(0x22),char(0x05),char(0x13),char(0x13),char(0xe7),char(0x13),char(0x2d),char(0xf1),char(0xf0),char(0x6e),char(0xd8),char(0x40),char(0xaa),char(0xe8),char(0x1b),
    char(0xAA) // json_metadata
  };
  try {
    my::operation result;
    result = my::unpack_from_char_array<my::operation>( buffer, sizeof(buffer) );
  } catch( fc::exception& _e ) {
    BOOST_TEST_MESSAGE( _e.what() );
  }
}
