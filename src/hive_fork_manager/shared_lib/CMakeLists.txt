#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET( target_name hfm-${GIT_REVISION} )

ADD_RUNTIME_LOADED_LIB( ${target_name} )

TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE "${PROJECT_SOURCE_DIR}/hive/libraries/protocol/include" )

TARGET_LINK_LIBRARIES( ${target_name} PUBLIC hive_protocol_shared fc_shared equihash_shared )

SET_TARGET_PROPERTIES( hive_protocol_shared fc_shared equihash_shared PROPERTIES INSTALL_RPATH ${POSTGRES_LIBDIR} )

INSTALL( TARGETS
  ${target_name} fc_shared hive_protocol_shared equihash_shared

  RUNTIME DESTINATION bin
  LIBRARY DESTINATION ./
  ARCHIVE DESTINATION lib
)

INSTALL(
    DIRECTORY
    ${PROJECT_BINARY_DIR}/hive/libraries/fc/vendor/secp256k1-zkp/src/project_secp256k1-build/.libs/
    DESTINATION
    ${POSTGRES_LIBDIR}
)

