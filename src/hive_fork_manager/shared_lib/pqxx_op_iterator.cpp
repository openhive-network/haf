// pqxx_op_iterator.cpp
#include "pqxx_op_iterator.hpp"
#include <hive/protocol/operations.hpp>

#include <iostream>
#include <iomanip>
#include <sstream>
#include <string_view>
#include <vector>

namespace consensus_state_provider {

bool pqxx_op_iterator::has_next() const
{
  return (cur_op != end_it) && (cur_op["block_num"].as<int>() == block_num);
}

hive::chain::op_iterator::op_view_t pqxx_op_iterator::unpack_from_char_array_and_next()
{
  pqxx::binarystring bs(cur_op["bin_body"]);
  const char* raw_data = reinterpret_cast<const char*>(bs.data());
  uint32_t data_length = bs.size();
 
  ++cur_op;

  return fc::raw::unpack_from_char_array<hive::protocol::operation>(raw_data, data_length);
}
}  // namespace consensus_state_provider