// pqxx_op_iterator.cpp
#include "pqxx_op_iterator.hpp"

bool pqxx_op_iterator::has_next() const
{
  return (cur_op != end_it) && (cur_op["block_num"].as<int>() == block_num);
}

std::vector<char> pqxx_op_iterator::next()
{
  pqxx::binarystring bs(cur_op["bin_body"]);
  const char* raw_data = reinterpret_cast<const char*>(bs.data());
  uint32_t data_length = bs.size();
  std::vector<char> op(raw_data, raw_data + data_length);

  ++cur_op;

  return op;
}