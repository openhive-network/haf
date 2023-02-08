#include <fc/exception/exception.hpp>

#include "svstream.hpp"

#include <string_view>

namespace fc {
  /**
   * An input stream backed by std::string_view
   */
  class svstream : public istream {
  public:
    svstream() = default;
    svstream(std::string_view s) : sv(s) {}
    virtual ~svstream() = default;

    size_t readsome(char* buf, size_t len) override;
    size_t readsome(const std::shared_ptr<char>& buf, size_t len, size_t offset) override;

    char get() override;

  private:
    std::string_view sv;
    size_t read_pos = 0;
  };
    
  size_t svstream::readsome( char* buf, size_t len )
  {
    if (read_pos < sv.length())
    {
      const size_t bytes_copied = std::min(len, sv.length() - read_pos);
      memcpy(buf, &sv[read_pos], bytes_copied);
      read_pos += bytes_copied;
      return bytes_copied;
    }
    FC_THROW_EXCEPTION( eof_exception, "svstream" );
  }

  size_t svstream::readsome( const std::shared_ptr<char>& buf, size_t len, size_t offset )
  {
    return readsome(buf.get() + offset, len);
  }

  char svstream::get()
  {
    if (read_pos < sv.length())
    {
      return sv[read_pos++];
    }
    FC_THROW_EXCEPTION( eof_exception, "svstream" );
  }


  istream_ptr make_svstream(const char* raw_data)
  {
    return std::make_shared<fc::svstream>(raw_data);
  }

} /// namespace fc

