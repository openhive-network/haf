#pragma once

#include <memory>
#include <vector>

extern "C" {
typedef struct pg_conn PGconn;
}

namespace PsqlTools::PostgresPQ {
  class CopyTuplesSession;

  class Transaction {
  public:
    explicit Transaction( std::shared_ptr< PGconn > _connection );
    virtual ~Transaction();

    void execute( const std::string& _sql ) const;
    std::unique_ptr< CopyTuplesSession > startCopyTuplesSession( const std::string& _table_name, const std::vector< std::string >& _columns );
  private:
    std::shared_ptr< PGconn > m_connection;
  };

} // namespace PsqlTools
