#pragma once

#include "psql_utils/postgres_includes.hpp"

#include <memory>

namespace PsqlTools::PsqlUtils {
    using bytea_ptr = std::unique_ptr< bytea, decltype(&std::free) >;

    template< typename _Data >
    bytea_ptr toBytea( _Data* _data ) {

      bytea_ptr result( static_cast<bytea*>( std::malloc(sizeof(_Data) + VARHDRSZ) ), &std::free );
      SET_VARSIZE( result.get(), sizeof( _Data ) );
      std::memcpy( VARDATA_ANY( result.get() ), _data, sizeof( _Data ) );

      return result;
    }
} //namespace PsqlTools::PsqUtils
