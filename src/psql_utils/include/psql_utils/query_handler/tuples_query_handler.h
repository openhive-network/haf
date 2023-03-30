#pragma once

#include "psql_utils/query_handler/root_query_handler.hpp"

#include <functional>
#include <optional>

namespace PsqlTools::PsqlUtils {

  /**
   *  Break a root query when more than given number of tuples are touched, or the execution timeout was exceeded
   */
  class TuplesQueryHandler : public RootQueryHandler {
  public:
    using Limit = uint32_t;
    using TuplesLimitGetter = std::function< Limit() >;

    explicit TuplesQueryHandler( TuplesLimitGetter _tuplesLimitGetter );

    void onRootQueryRun( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) override;
    void onSubQueryRun( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) override;
    void onRootQueryFinish( QueryDesc* _queryDesc ) override;
    void onSubQueryFinish( QueryDesc* _queryDesc ) override;

  private:
    void addInstrumentation( QueryDesc* _queryDesc ) const;
    void checkTuplesLimit();

  private:
    std::optional< Limit > m_limitOfTuplesPerRootQuery = std::nullopt;
    const TuplesLimitGetter m_tuplesLimitGetter;
  };

} // namespace PsqlTools::PsqlUtils