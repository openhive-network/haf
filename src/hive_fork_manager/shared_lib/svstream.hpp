#pragma once
#include <fc/io/iostream.hpp>

#include <string_view>

namespace fc {

  // TODO: move this to fc
  /**
   * An input stream backed by std::string_view
   */
  class svstream : public istream {
    public:
      svstream();
      svstream( std::string_view s);
      ~svstream();

      size_t readsome( char* buf, size_t len ) override;
      size_t readsome( const std::shared_ptr<char>& buf, size_t len, size_t offset ) override;

      char get() override;

    private:
      std::string_view sv;
      size_t read_pos = 0;
  };

}
