#pragma once;

#include "include/psql_utils/query_handler/timeout_query_handler.h"

namespace PsqlTools::PsqlUtils {

  class TuplesQueryHandler : public TimeoutQueryHandler {
  public:
    TuplesQueryHandler() = default;

    void onRunQuery( QueryDesc* _queryDesc ) override;
    void onFinishQuery( QueryDesc* _queryDesc ) override;
    void onPeriodicCheck() override;

  private:
    void addInstrumentation( QueryDesc* _queryDesc ) const;
  };

} // namespace PsqlTools::PsqlUtils