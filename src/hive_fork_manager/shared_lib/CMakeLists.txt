#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET( target_name hfm-${HAF_GIT_REVISION_SHA} )

ADD_RUNTIME_LOADED_LIB( TARGET_NAME ${target_name} LINK_WITH hive_protocol fc_shared_boost )

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

