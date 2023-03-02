#include "timeout_query_handler.h"

#include "include/psql_utils/logger.hpp"

#include <future>
#include <thread>
#include <sstream>
#include <string>

#include <sys/types.h>
#include <unistd.h>

bool allow_to_break = false;
std::future<void> timeout_future;
QueryDesc* root_queryDesc = nullptr;


namespace PsqlTools::QuerySupervisor {
  TimeoutQueryHandler::TimeoutQueryHandler() {

  }

  void TimeoutQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    LOG_INFO( "MIC: Query start %d %s", gettid(), _queryDesc->sourceText );
    allow_to_break = true;
    if (root_queryDesc) // means we are in subquery (ie. query inside function), else -we are at the root of all queries
      return;
    root_queryDesc = _queryDesc;
    LOG_INFO( "MIC: Root Query start %d %s", gettid(), _queryDesc->sourceText );

    auto thread_body = []{
      LOG_INFO( "MIC: thread start %d", gettid() );
      sleep(1);
      LOG_INFO( "MIC: after sleep" );
      if (allow_to_break) {
        LOG_INFO( "MIC: sigint fire" );
        allow_to_break = false;
        root_queryDesc = nullptr;
        StatementCancelHandler(0);
      }
    };


    LOG_INFO( "MIC: before thread start" );
    auto future = std::move( std::async( std::launch::async, thread_body) );
    timeout_future = std::move( future );
    LOG_INFO( "MIC: after thread start" );
  }

  void TimeoutQueryHandler::onEndQuery( QueryDesc* _queryDesc ) {
    LOG_INFO( "MIC: 0 Query stop after future %d %s", gettid(), _queryDesc->sourceText );
    if ( root_queryDesc == _queryDesc ) { //end of root query
      allow_to_break = false;
      root_queryDesc = nullptr;
      LOG_INFO( "MIC: Query stop %d %s", gettid(), _queryDesc->sourceText );
      try {
        timeout_future.get();
        timeout_future = std::future<void>();
      } catch(...){ LOG_INFO( "MIC: future exception"); }
      LOG_INFO( "MIC: Query stop after future %d %s", gettid(), _queryDesc->sourceText );
    }
    else {
      LOG_INFO( "MIC: End of non-root Query stop %d %s", gettid(), _queryDesc->sourceText );
      return;
    }

  }
} // namespace PsqlTools::QuerySupervisor
