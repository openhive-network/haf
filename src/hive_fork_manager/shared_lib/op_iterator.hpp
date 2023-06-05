#include <utility>

class op_iterator
{
 public:
  virtual ~op_iterator() = default;
  virtual bool has_next() const = 0;
  virtual std::pair<const void*, std::size_t> next() = 0;
};
