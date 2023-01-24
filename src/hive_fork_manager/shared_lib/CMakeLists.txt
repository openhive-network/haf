#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET( target_name hfm-${HAF_GIT_REVISION_SHA} )

ADD_RUNTIME_LOADED_LIB( ${target_name} )

TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE "${PROJECT_SOURCE_DIR}/hive/libraries/protocol/include" )


SET (ORIGINAL_LIB_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES} )
SET (CMAKE_FIND_LIBRARY_SUFFIXES .so)
# using a new HAF_PQXX_LIB variable and not reusing PQXX_LIB variable because it is already set by the sql_serializer to static
FIND_LIBRARY(HAF_PQXX_LIB pqxx REQUIRED)
FIND_LIBRARY(HAF_PQ_LIB pq REQUIRED)
# restore
SET (CMAKE_FIND_LIBRARY_SUFFIXES ${ORIGINAL_LIB_SUFFIXES} )

add_definitions(-DHAF_SHARED_LIB )

TARGET_LINK_LIBRARIES( ${target_name} PUBLIC hive_protocol fc_shared_boost database_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})

INSTALL( TARGETS
  ${target_name}

  RUNTIME DESTINATION bin
  LIBRARY DESTINATION ./
  ARCHIVE DESTINATION lib
)

INSTALL(
    DIRECTORY
    DESTINATION
    ${POSTGRES_LIBDIR}
)

