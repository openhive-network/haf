#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET( target_name hfm-${HAF_GIT_REVISION_SHA} )

# ADD_RUNTIME_LOADED_LIB( TARGET_NAME ${target_name} LINK_WITH hive_protocol fc_shared_boost )
FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )

#ADD_LIBRARY( ${target_name} SHARED ${sources} )
ADD_EXECUTABLE( ${target_name}  ${sources} )


SETUP_COMPILER( ${target_name} )
SETUP_CLANG_TIDY( ${target_name} )

ADD_POSTGRES_INCLUDES( ${target_name} )
ADD_POSTGRES_LIBRARIES( ${target_name} )

message(STATUS "LIBRARY_LINK_WITH=${LIBRARY_LINK_WITH}")
TARGET_LINK_LIBRARIES( ${target_name} PUBLIC ${LIBRARY_LINK_WITH} )



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

