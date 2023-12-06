#include "extract_set_witness_properties.hpp"

#include <hive/protocol/types.hpp>
#include <hive/protocol/asset.hpp>

#include <fc/io/json.hpp>
#include <fc/io/raw.hpp>

using namespace hive::protocol;
using witness_set_properties_props_t = fc::flat_map< fc::string, std::vector< char > >;

struct wsp_fill_helper
{
  const witness_set_properties_props_t& source;
  extract_set_witness_properties_result_t& result;

  template<typename T>
  void try_fill(const fc::string& pname, const fc::string& alt_pname = fc::string{})
  {
    auto itr = source.find( pname );

    if( itr == source.end() && alt_pname != fc::string{} )
      itr = source.find( alt_pname );

    if(itr != source.end())
    {
      T unpack_result;
      fc::raw::unpack_from_vector<T>(itr->second, unpack_result);
      result[pname] = fc::json::to_string(unpack_result);
    }
  }
};

void extract_set_witness_properties_from_flat_map(extract_set_witness_properties_result_t& output, const fc::flat_map<fc::string, std::vector<char>>& _input)
{
  wsp_fill_helper helper{ _input, output };

  helper.try_fill<public_key_type>("key");
  helper.try_fill<asset>("account_creation_fee");
  helper.try_fill<uint32_t>("maximum_block_size");
  helper.try_fill<uint16_t>("hbd_interest_rate", "sbd_interest_rate");
  helper.try_fill<int32_t>("account_subsidy_budget");
  helper.try_fill<uint32_t>("account_subsidy_decay");
  helper.try_fill<public_key_type>("new_signing_key");
  helper.try_fill<price>("hbd_exchange_rate", "sbd_exchange_rate");
  helper.try_fill<fc::string>("url");
}

void extract_set_witness_properties_from_string(extract_set_witness_properties_result_t& output, const fc::string& _input)
{
  witness_set_properties_props_t input_properties{};
  fc::from_variant(fc::json::from_string(_input, fc::json::format_validation_mode::relaxed), input_properties);
  extract_set_witness_properties_from_flat_map(output, input_properties);
}
