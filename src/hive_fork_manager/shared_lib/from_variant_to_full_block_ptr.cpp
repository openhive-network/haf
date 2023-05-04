


#include <hive/chain/hive_fwd.hpp>

#include <appbase/application.hpp>

#include <hive/plugins/block_api/block_api_objects.hpp>
#include <hive/plugins/database_api/database_api.hpp>
#include <hive/plugins/database_api/database_api_plugin.hpp>

#include <hive/protocol/get_config.hpp>
#include <hive/protocol/exceptions.hpp>
#include <hive/protocol/transaction_util.hpp>
#include <hive/protocol/forward_impacted.hpp>

#include <hive/chain/util/smt_token.hpp>

#include <hive/utilities/git_revision.hpp>


namespace consensus_state_provider
{

struct fix_hf_version_visitor
{
  fix_hf_version_visitor(int a_proper_version):proper_version(a_proper_version){}

  typedef void result_type;

  void operator()(  hive::void_t& obj ) const
  {
    //Nothing to do.
  }

  void operator()(  hive::protocol::version& reported_version ) const
  {
    //Nothing to do.
  }

  void operator()(  hive::protocol::hardfork_version_vote& hfv ) const
  {
    auto& ver = hfv.hf_version;
    static_cast<hive::protocol::version&>(ver) = hive::protocol::version( 0, 0, proper_version);
  }

private:
  int proper_version;
};

void fix_hf_version(hive::plugins::block_api::api_signed_block_object& sb, int proper_hf_version, int block_num_debug)
{
    fix_hf_version_visitor visitor(proper_hf_version);

    for (auto& extension : sb.extensions)
    {
        extension.visit(visitor);
    }
    wlog("fixing with fix_hf_version block ${block_num_debug}", ("block_num_debug", block_num_debug));
}


std::shared_ptr<hive::chain::full_block_type> from_variant_to_full_block_ptr(const fc::variant& v, int block_num_debug )
{
  hive::plugins::block_api::api_signed_block_object sb;

  fc::from_variant( v, sb );

  switch(block_num_debug)
  {
    case 2726331: fix_hf_version(sb, 489, block_num_debug); break;
    case 2730591: fix_hf_version(sb, 118, block_num_debug); break;
    case 2733423: fix_hf_version(sb, 119, block_num_debug); break;
    case 2768535: fix_hf_version(sb, 116, block_num_debug); break;
    case 2781318: fix_hf_version(sb, 116, block_num_debug); break;
    case 2786287: fix_hf_version(sb, 119, block_num_debug); break;
  }


  if(block_num_debug == 994240 || block_num_debug == 1021529)
  {
    auto& op = sb.transactions[0].operations[0].get<hive::protocol::witness_update_operation>();
    op.props.account_creation_fee.symbol.ser = 0x4d4545545301;
    //4d 45 45 54 53   03 

  }

  return hive::chain::full_block_type::create_from_signed_block(sb);
}

}