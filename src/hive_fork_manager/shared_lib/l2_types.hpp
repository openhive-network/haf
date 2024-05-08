#include <hive/protocol/types.hpp>

#include <boost/container/flat_set.hpp>

#include<vector>

namespace l2
{
  using hive::protocol::signature_type;
  using hive::protocol::public_key_type;
  using hive::protocol::digest_type;
  using hive::protocol::chain_id_type;

  using boost::container::flat_set;

  struct public_keys
  {
    flat_set<public_key_type> keys;
  };

  struct operation
  {
    std::string type;
    std::string value;
  };

  struct signature
  {
    signature_type signature;
  };

  struct transaction
  {
    std::vector<operation> operations;
    std::vector<signature> signatures;

    digest_type sig_digest( const chain_id_type& chain_id ) const;
    flat_set<public_key_type> get_signature_keys( const chain_id_type& chain_id ) const;
  };

}

FC_REFLECT( l2::public_keys, (keys) )
FC_REFLECT( l2::operation, (type)(value) )
FC_REFLECT( l2::signature, (signature) )
FC_REFLECT( l2::transaction, (operations)(signatures) )
