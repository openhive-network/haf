#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET( target_name variant-${GIT_REVISION} )

ADD_RUNTIME_LOADED_LIB( ${target_name} )

# Fix for the PostgreSQL variant C flags setting
if( ${POSTGRES_VERSION} LESS 9 )
  set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DOVERRIDE_FINFO" )
else()
  set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DLONG_PARSETYPE" )
endif()

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
