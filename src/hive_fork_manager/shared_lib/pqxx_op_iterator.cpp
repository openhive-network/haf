// pqxx_op_iterator.cpp
#include "pqxx_op_iterator.hpp"

bool pqxx_op_iterator::has_next() const
{
  return (cur_op != end_it) && (cur_op["block_num"].as<int>() == block_num);
}

std::pair<const void*, size_t> pqxx_op_iterator::next()
{
  pqxx::binarystring bs(cur_op["bin_body"]);
  const void* raw_data = bs.data();
  size_t data_length = bs.size();

  ++cur_op;

  return {raw_data, data_length};
}