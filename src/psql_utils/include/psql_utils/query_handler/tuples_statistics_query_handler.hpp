#pragma once

#include "psql_utils/query_handler/root_query_handler.hpp"

#include <functional>
#include <optional>
#include <unordered_map>

namespace PsqlTools::PsqlUtils {

  /**
   *  Break a root query when more than given number of tuples are touched, or the execution timeout was exceeded
   */
  class TuplesStatisticsQueryHandler : public RootQueryHandler {
  public:
    using Limit = uint32_t;
    using Counter = uint32_t;
    using TuplesLimitGetter = std::function< Limit() >;
    using CommandFilterFlag = uint8_t;

    enum class SqlCommand{
          SELECT = 0x01
        , UPDATE = 0x02
        , INSERT = 0x04
        , DELETE = 0x08
        , OTHER  = 0x10
    };

    explicit TuplesStatisticsQueryHandler();

    using Statistics = std::unordered_map< SqlCommand, Counter >;
    const Statistics& getStatistics() const {return m_statistics; }
    Counter numberOfAllTuples() const { return m_numberOfAllTuples; }

  protected:
    // class which inherits make decision if based on the current statistics the query needs to be stopped
    // default implementation always return false - does not allow to stop a pending query
    virtual bool breakQuery() const;

  private:
    void onRootQueryRun( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) final;
    void onSubQueryRun( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) final;
    void onRootQueryFinish( QueryDesc* _queryDesc ) final;
    void onSubQueryFinish( QueryDesc* _queryDesc ) final;

    void addInstrumentation( QueryDesc* _queryDesc ) const;
    void checkTuplesLimit();
    void updateStatistics( const QueryDesc& _queryDesc );
    void resetStatistics();

    SqlCommand cmdTypeToFilter(CmdType ) const;

  private:
    Statistics m_statistics;
    Counter m_numberOfAllTuples = {0};
  };
} // namespace PsqlTools::PsqlUtils