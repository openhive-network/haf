#pragma once

#include "include/psql_utils/query_handler/timeout_query_handler.h"

namespace PsqlTools::PsqlUtils {

  /**
   *  Break a query when more than given number of tuples are touched, or the execution timeout was exceeded
   */
  class TuplesQueryHandler : public TimeoutQueryHandler {
  public:
    TuplesQueryHandler( uint32_t _limitOfTuplesPerRootQuery, std::chrono::milliseconds _queryTimeout );

    void onStartQuery( QueryDesc* _queryDesc, int _eflags ) override;
    void onEndQuery( QueryDesc* _queryDesc ) override;
    void onRunQuery( QueryDesc* _queryDesc ) override;
    void onFinishQuery( QueryDesc* _queryDesc ) override;
    void onPeriodicCheck() override;

  private:
    void addInstrumentation( QueryDesc* _queryDesc ) const;

  private:
    const uint32_t m_limitOfTuplesPerRootQuery;
  };

} // namespace PsqlTools::PsqlUtils