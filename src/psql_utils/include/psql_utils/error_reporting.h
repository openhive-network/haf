#pragma once

#include "psql_utils/postgres_includes.hpp"

#include "fc/exception/exception.hpp"

#include <string>
#include <optional>
#include <stdexcept>

namespace PsqlTools::PsqlUtils {

  /**
   * Exception thrown by cxx_call_pg when executed function raise an ERROR.
   */
  struct PgError : public std::runtime_error {
    PgError(const char* msg) : std::runtime_error(msg)
    {}
  };

  /**
   * This function is a safe way to invoke lambda with C++ code from Postgres code.
   * This catches any exception thrown by called lambda and translates them into Postgres errors using ereport call.
   * This also catches any Postgres errors raised from lambda unguarded by PG_TRY,PG_CATCH.
   * If any result is needed to be returned from c++, it should be captured and modified inside lambda.
   */
  template <typename F>
  void pg_call_cxx(F f, int errorcode=ERRCODE_DATA_EXCEPTION)
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
       error_message = "Unexpected error calling cpp function";
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

  /**
   * Function intended to wrap calls to Postgres functions from c++ code.
   * This catches any ERROR and turns it into c++ exception, so that any c++ object in the calling code can be properly destructed.
   * Intended to be used with pg_call_cxx to turn the exception back into ERROR to be passed to calling Postgres code.
   *
   * This is intended for calling a single Postgres function that can raise an ERROR.
   * Any exception thrown by called function is transformed into PgError exception.
   */
  template <typename Fp, typename... Args>
  auto cxx_call_pg(Fp&& f, Args&&... args) -> std::invoke_result_t<Fp, Args...>
  {
    using RetType = std::invoke_result_t<Fp, Args...>;

    std::optional<RetType> ret;
    const char* error_message = nullptr;
    MemoryContext oldcontext = CurrentMemoryContext;
    PG_TRY();
    {
      const char* emsg = nullptr;
      try
      {
        ret = f(std::forward<Args>(args)...);
      }
      catch (const fc::exception& e)
      {
        const auto msg = e.to_string();
        emsg = pnstrdup(msg.c_str(), msg.length());
      }
      catch (const std::exception& e)
      {
        emsg = pstrdup(e.what());
      }
      catch (...)
      {
       emsg = "Unexpected error calling pg function";
      }
      if (!ret.has_value()) ereport( ERROR, ( errmsg( "%s", emsg ) ) );
    }
    PG_CATCH();
    {
      MemoryContext errorContext = MemoryContextSwitchTo(oldcontext);
      ErrorData *edata = CopyErrorData();
      error_message = edata->message;
      MemoryContextSwitchTo(errorContext);
    }
    PG_END_TRY();
    if (ret.has_value()) return ret.value();
    else throw PgError(error_message ? error_message : "");
  }

  template <size_t N>
  struct DirectFunctionCallNColl
  { static_assert(N != N, "Missing specialisation for DirectFunctionCallNColl for requested value of N"); };
  template <>
  struct DirectFunctionCallNColl<1>
  { constexpr static auto value = DirectFunctionCall1Coll; };
  template <>
  struct DirectFunctionCallNColl<2>
  { constexpr static auto value = DirectFunctionCall2Coll; };
  template <>
  struct DirectFunctionCallNColl<3>
  { constexpr static auto value = DirectFunctionCall3Coll; };
  template <>
  struct DirectFunctionCallNColl<4>
  { constexpr static auto value = DirectFunctionCall4Coll; };
  template <>
  struct DirectFunctionCallNColl<5>
  { constexpr static auto value = DirectFunctionCall5Coll; };
  template <>
  struct DirectFunctionCallNColl<6>
  { constexpr static auto value = DirectFunctionCall6Coll; };
  template <>
  struct DirectFunctionCallNColl<7>
  { constexpr static auto value = DirectFunctionCall7Coll; };
  template <>
  struct DirectFunctionCallNColl<8>
  { constexpr static auto value = DirectFunctionCall8Coll; };
  template <>
  struct DirectFunctionCallNColl<9>
  { constexpr static auto value = DirectFunctionCall9Coll; };

  /**
   * Same as cxx_call_pg, but automatically call provided function via correct DirectFunctionCallXColl Postgres function, so that the caller doesn't have to.
   * Fp needs to return Datum.
   */
  template <typename Fp, typename... Args>
  auto cxx_direct_call_pg(Fp&& f, Args&&... args) -> Datum
  {
    auto DirectFunctionCallN = DirectFunctionCallNColl<sizeof...(Args)>::value;
    return cxx_call_pg(DirectFunctionCallN, std::forward<Fp>(f), InvalidOid, std::forward<Args>(args)...);
  }

} // namespace PsqlTools::PsqlUtils
