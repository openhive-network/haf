// pqxx_op_iterator.cpp
#include "pqxx_op_iterator.hpp"
#include <hive/protocol/operations.hpp>


#include <iostream>
#include <iomanip>
#include <sstream>
#include <string_view>
#include <vector>


bool pqxx_op_iterator::has_next() const
{
  return (cur_op != end_it) && (cur_op["block_num"].as<int>() == block_num);
}

op_iterator::op_view_t pqxx_op_iterator::unpack_from_char_array_and_next()
{
  pqxx::binarystring bs(cur_op["bin_body"]);
  const char* raw_data = reinterpret_cast<const char*>(bs.data());
  uint32_t data_length = bs.size();
  // std::vector<char> op(raw_data, raw_data + data_length);
  // std::string_view s(raw_data, data_length);

  // std::cout << "Inside next: " << std::endl;
  // std::cout << "Memory at raw_data in hex: " << std::endl << to_hex(raw_data, data_length) << std::endl;

  //   std::cout << "raw_data in hex: " << std::endl << to_hex(raw_data, data_length) << std::endl;
  //   std::cout << "data_length in hex: " << std::endl << std::hex << data_length << std::endl;
  //   std::cout << "op in hex: " << std::endl << to_hex(op.data(), op.size()) << std::endl;
  //   std::cout << "s in hex: " << std::endl << to_hex(s.data(), s.size()) << std::endl;

  



  ++cur_op;

  return fc::raw::unpack_from_char_array<hive::protocol::operation>(raw_data, data_length);
}