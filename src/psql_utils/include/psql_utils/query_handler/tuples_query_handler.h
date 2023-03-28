#pragma once

#include "psql_utils/query_handler/root_query_handler.hpp"

namespace PsqlTools::PsqlUtils {

  /**
   *  Break a query when more than given number of tuples are touched, or the execution timeout was exceeded
   */
  class TuplesQueryHandler : public RootQueryHandler {
  public:
    explicit TuplesQueryHandler( uint32_t _limitOfTuplesPerRootQuery );

    void onRootQueryRun( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) override;
    void onSubQueryRun( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) override;
    void onRootQueryFinish( QueryDesc* _queryDesc ) override;
    void onSubQueryFinish( QueryDesc* _queryDesc ) override;

  private:
    void addInstrumentation( QueryDesc* _queryDesc ) const;
    void checkTuplesLimit();

  private:
    const uint32_t m_limitOfTuplesPerRootQuery;
  };

} // namespace PsqlTools::PsqlUtils