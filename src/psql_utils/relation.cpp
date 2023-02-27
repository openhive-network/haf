#include "include/psql_utils/relation.hpp"

#include "relation_from_name.hpp"
#include "relation_wrapper.hpp"

namespace PsqlTools::PsqlUtils {

  std::unique_ptr< IRelation >
  IRelation::create( const std::string& _relation_name ) {
    return std::make_unique< RelationFromName >( _relation_name );
  }

  std::unique_ptr< IRelation >
  IRelation::create( RelationData* _relation_data ) {
    return std::make_unique< RelationWrapper >( _relation_data );
  }
} // namespace PsqlTools::PsqlUtils

