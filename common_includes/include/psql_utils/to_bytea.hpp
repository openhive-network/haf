#pragma once

#include "include/psql_utils/postgres_includes.hpp"

#include <memory>

namespace PsqlTools::PsqlUtils {

    template< typename _Data >
    std::unique_ptr< bytea > toBytea( _Data* _data ) {
      std::unique_ptr< bytea > result( ( bytea* )new uint8_t[ sizeof( _Data ) + VARHDRSZ ] );
      SET_VARSIZE( result.get(), sizeof( _Data ) );
      std::memcpy( VARDATA_ANY( result.get() ), _data, sizeof( _Data ) );

      return result;
    }
} //namespace PsqlTools::PsqUtils
