#pragma once

#include <memory>
#include <string>
#include <vector>

extern "C" {
  struct pg_conn;
}

namespace PsqlTools::PostgresPQ {

  class CopySession{
  public:
    CopySession( std::shared_ptr< pg_conn > _connection, const std::string& _table_name, const std::vector< std::string >& _columns );
    ~CopySession();
    CopySession(const CopySession&) = delete;
    CopySession& operator=(const CopySession&) = delete;

    std::string get_table_name() const;

    template< typename _PushedType >
    void push_data( const _PushedType* _data, uint32_t _size ) const;

  private:
    void push_data_internal( const char* _data, uint32_t _size ) const;

  private:
    std::shared_ptr< pg_conn > m_connection;
    const std::string m_table_name;
  };

  template< typename _PushedType >
  inline void
  CopySession::push_data( const _PushedType* _data, uint32_t _size  ) const {
    push_data_internal( reinterpret_cast< const char* >( _data ), _size );
  }

} // namespace PsqlTools

