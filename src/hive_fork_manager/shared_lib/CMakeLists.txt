#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET( target_name hfm-${HAF_GIT_REVISION_SHA} )

ADD_RUNTIME_LOADED_LIB( ${target_name} )

TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE "${PROJECT_SOURCE_DIR}/hive/libraries/protocol/include" )

TARGET_LINK_LIBRARIES( ${target_name} PUBLIC hive_protocol fc equihash )

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

