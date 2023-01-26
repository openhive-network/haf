#include <fc/exception/exception.hpp>

#include "svstream.hpp"

#include <string_view>

namespace fc {
  svstream::svstream()
  {}
  svstream::svstream( std::string_view sv )
    : sv(sv)
  {}
  svstream::~svstream()
  {}

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

}
