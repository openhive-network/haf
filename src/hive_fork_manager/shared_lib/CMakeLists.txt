#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET( target_name hfm-${HAF_GIT_REVISION_SHA} )

add_definitions(-DCSP)


ADD_RUNTIME_LOADED_LIB( TARGET_NAME ${target_name} LINK_WITH hive_protocol fc_shared_boost )

# Preserve the original library suffixes to restore them later.
SET (SAVE_ORIGINAL_LIB_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})

# Override the library suffixes to specifically look for shared libraries (.so).
SET (CMAKE_FIND_LIBRARY_SUFFIXES .so)

# Search for the required shared libraries for pqxx and pq.
# Note: We're using HAF_PQXX_LIB instead of PQXX_LIB as the latter is used by sql_serializer for static linking.
FIND_LIBRARY(HAF_PQXX_LIB pqxx REQUIRED)
FIND_LIBRARY(HAF_PQ_LIB pq REQUIRED)

# Restore the original library suffixes after searching for our required libraries.
SET (CMAKE_FIND_LIBRARY_SUFFIXES ${SAVE_ORIGINAL_LIB_SUFFIXES})


TARGET_LINK_LIBRARIES( ${target_name} PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})



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

