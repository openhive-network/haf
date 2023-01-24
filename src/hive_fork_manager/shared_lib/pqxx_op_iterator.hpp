#pragma once
#include <hive/chain/op_iterator.hpp>

#include <pqxx/pqxx>

namespace consensus_state_provider {

class pqxx_op_iterator : public hive::chain::op_iterator
{
 private:
  pqxx::result::const_iterator& cur_op;
  pqxx::result::const_iterator end_it;
  int block_num;

 public:
  pqxx_op_iterator(pqxx::result::const_iterator& start,
                   const pqxx::result::const_iterator& end,
                   int block)
      : cur_op(start), end_it(end), block_num(block)
  {
  }

  bool has_next() const override;
  op_view_t unpack_from_char_array_and_next() override;
};

}  // namespace consensus_state_provider