#include <fc/string.hpp>
#include <fc/container/flat_fwd.hpp>

#include <vector>

using extract_set_witness_properties_result_t = fc::flat_map<fc::string, fc::string>;

void extract_set_witness_properties_impl(extract_set_witness_properties_result_t& output, const fc::string& _input);
