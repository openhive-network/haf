#include "psql_utils/query_handler/timeout_query_handler.h"

#include "psql_utils/custom_configuration.h"
#include "psql_utils/logger.hpp"

#include <atomic>
#include <string>
#include <condition_variable>
#include <mutex>

#include <csignal>

namespace {
  std::condition_variable g_cvSignalsThread;
  std::mutex g_cvSignalsThreadMutex;
  std::atomic<bool> g_stopSignalsThread = false;
  std::atomic<bool> g_breakPendingQuery = false;

  void timeoutHandler() {
    LOG_WARNING( "The query was terminated due to a timeout being reached." );
      g_breakPendingQuery = true;
      g_cvSignalsThread.notify_one();
  }



    void signalsThreadBody() {
        // Block all signals in this thread
        sigset_t set;
        sigfillset(&set);
        pthread_sigmask(SIG_BLOCK, &set, nullptr);

        std::unique_lock<std::mutex> lock(g_cvSignalsThreadMutex);
        while (true) {
            g_cvSignalsThread.wait(lock, [] { return g_stopSignalsThread || g_breakPendingQuery; });
            if (g_breakPendingQuery) {
                kill(MyProcPid, SIGINT);
                g_breakPendingQuery = false;
            }

            if (g_stopSignalsThread) {
                return;
            }
        }
    }


} // namespace

namespace PsqlTools::PsqlUtils {
  TimeoutQueryHandler::TimeoutQueryHandler( TimeoutLimitGetter _limitGetter  )
    : m_timeoutLimitGetter( _limitGetter )
    , m_breakingThread( signalsThreadBody )
  {
    // no worries about fail of registration because pg will terminate backend
    m_pendingQueryTimeout = RegisterTimeout( USER_TIMEOUT, timeoutHandler );
  }

  TimeoutQueryHandler::~TimeoutQueryHandler() {
    disable_timeout( m_pendingQueryTimeout, true );

    g_stopSignalsThread = true;
    g_cvSignalsThread.notify_one();

    m_breakingThread.join();
  }

  void TimeoutQueryHandler::onRootQueryStart( QueryDesc* _queryDesc, int _eflags ) {
    assert(_queryDesc);
    g_breakPendingQuery = false;
    spawnTimer();
  }

  void TimeoutQueryHandler::onRootQueryEnd( QueryDesc* _queryDesc ) {
    assert(_queryDesc);
    disable_timeout( m_pendingQueryTimeout, false );
    g_breakPendingQuery = false;
  }

  void TimeoutQueryHandler::onError(const QueryDesc& _queryDesc) {
    disable_timeout( m_pendingQueryTimeout, false );
    g_breakPendingQuery = false;
    RootQueryHandler::onError(_queryDesc);
  }

  void TimeoutQueryHandler::spawnTimer() {
    assert( m_timeoutLimitGetter );
    enable_timeout_after( m_pendingQueryTimeout, m_timeoutLimitGetter().count() );
  }
} // namespace PsqlTools::PsqlUtils
