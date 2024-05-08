#include "l2_types.hpp"

#include <fc/exception/exception.hpp>

namespace l2
{
  using hive::protocol::serialization_mode_controller;
  using hive::protocol::pack_type;

  digest_type transaction::sig_digest( const chain_id_type& chain_id ) const
  {
    digest_type::encoder enc;

    hive::protocol::serialization_mode_controller::pack_guard guard( pack_type::hf26 );
    fc::raw::pack( enc, chain_id );
    fc::raw::pack( enc, *this );

    return enc.result();
  }

  flat_set<public_key_type> transaction::get_signature_keys( const chain_id_type& chain_id ) const
  {
    auto _digest = sig_digest( chain_id );

    flat_set<public_key_type> _result;
    for( const auto&  sig : signatures )
    {
      FC_ASSERT( _result.insert( fc::ecc::public_key( sig.signature, _digest, fc::ecc::canonical_signature_type::bip_0062 ) ).second, "Duplicate Signature detected" );
    }

    return _result;
  }
}
