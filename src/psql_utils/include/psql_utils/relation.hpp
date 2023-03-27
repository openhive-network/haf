#pragma once

#include "psql_utils/columns_iterator.hpp"

#include <memory>
#include <string>
#include <vector>

extern "C" {
  struct varlena;
  typedef struct varlena bytea;
  struct RelationData;
}

namespace PsqlTools::PsqlUtils {
  class IRelation {
    public:
      using PrimaryKeyColumns = std::vector< uint16_t >;

      virtual ~IRelation() = default;

      virtual PrimaryKeyColumns getPrimaryKeysColumns() const = 0;
      virtual ColumnsIterator getColumns() const = 0;
      virtual std::string createPkeyCondition( bytea* _relation_tuple_in_copy_format ) const = 0;
      virtual std::string createRowValuesAssignment(bytea* _relation_tuple_in_copy_format ) const = 0;
      virtual std::string getName() const = 0;

      static std::unique_ptr< IRelation > create( const std::string& _relation_name );
      static std::unique_ptr< IRelation > create( RelationData* _relation_data );
  };
} // namespace PsqlTools::PsqlUtils

