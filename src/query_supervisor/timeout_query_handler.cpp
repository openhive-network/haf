#include "timeout_query_handler.h"

#include "include/psql_utils/logger.hpp"

namespace PsqlTools::QuerySupervisor {
  TimeoutQueryHandler::TimeoutQueryHandler() {

  }

  void TimeoutQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    LOG_INFO( "MIC: Query start" );
  }

  void TimeoutQueryHandler::onEndQuery( QueryDesc* _queryDesc ) {
    LOG_INFO( "MIC: Query stop" );
  }
} // namespace PsqlTools::QuerySupervisor
