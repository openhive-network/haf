#pragma once

#include "psql_utils/postgres_includes.hpp"

#include "fc/exception/exception.hpp"

#include <string>
#include <stdexcept>

namespace PsqlTools::PsqlUtils {

  class PostgresException {
  public:
    PostgresException(std::string str) : message(str)
    {}
    PostgresException(const std::exception& e) : message(e.what())
    {}
    PostgresException(const fc::exception& e) : message(e.to_string())
    {}

    const std::string& msg() const
    {
      return message;
    }

  private:
    std::string message;
  };

  /**
   * This function is a safe way to invoke lambda with C++ code from Postgres code.
   * This catches any exception thrown by called lambda and translates them into Postgres errors using ereport call.
   * This also catches any Postgres errors raised from lambda unguarded by PG_TRY,PG_CATCH.
   * If any result is needed to be returned from c++, it should be captured and modified inside lambda.
   */
  template <typename F>
  void call_cxx(F f, int errorcode=ERRCODE_DATA_EXCEPTION)
  {
    // We want lambda to contain only trivial captures, so that it's safe to be `longjmp`ed over.
    // We could use is_trivial_v, but in C++17 compilers disagree whether type of lambda is trivial or not. The standard explicitly says it's implementation defined.
    // So instead we use is_trivially_destructible_v. All of clang,gcc,msvc agree that type of a lambda is trivially destructible if all its captures are.
    static_assert(std::is_trivially_destructible_v<F>);
    // volatile to silence 'might be clobbered by ‘longjmp’ or ‘vfork’' warning
    const char* volatile error_message = nullptr;
    volatile MemoryContext oldcontext = CurrentMemoryContext;
    PG_TRY();
    {
      try
      {
        f();
      }
      catch (const PsqlTools::PsqlUtils::PostgresException& e)
      {
        error_message = pstrdup(e.msg().c_str());
      }
      catch (const fc::exception& e)
      {
        const auto msg = e.to_string();
        error_message = pnstrdup(msg.c_str(), msg.length());
      }
      catch (const std::exception& e)
      {
        error_message = pstrdup(e.what());
      }
      catch (...)
      {
       error_message = "Unexpected error";
      }
    } /* PG_TRY() */
    PG_CATCH();
    {
      // If we're here, it most likely means we got an error from Postgres function  we called without guarding PG_TRY/PG_CATCH.
      // This most likely caused some C++ object to be `longjmp`ed over without proper destruction.
      //
      // We're in ErrorContext now, but CopyErrorData should not be called from that context, so we switch temporarily to context from before PG_TRY.
      // Once we get the copy of error data, switch back to ErrorContext and report error.
      MemoryContext errorContext = MemoryContextSwitchTo(oldcontext);
      ErrorData *edata = CopyErrorData();
      MemoryContextSwitchTo(errorContext);
      ereport( ERROR, ( errmsg( "An unexpected error occurred when executing C++ code: %s", edata->message ) ) );
    }
    PG_END_TRY();
    if ( error_message )
      ereport( ERROR, ( errcode( errorcode ), errmsg( "%s", error_message) ) );
  }

} // namespace PsqlTools::PsqlUtils
