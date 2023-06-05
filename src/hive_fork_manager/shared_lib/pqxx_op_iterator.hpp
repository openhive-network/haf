#pragma once 
#include <hive/chain/op_iterator.hpp>

#include <pqxx/pqxx>

class pqxx_op_iterator : public op_iterator
{
 private:
  pqxx::result::const_iterator cur_op, end_it;
  int block_num;

 public:
  pqxx_op_iterator(const pqxx::result::const_iterator& start,
                   const pqxx::result::const_iterator& end,
                   int block)
      : cur_op(start), end_it(end), block_num(block)
  {
  }

  bool has_next() const override;
  std::pair<const void*, std::size_t> next() override;
};
