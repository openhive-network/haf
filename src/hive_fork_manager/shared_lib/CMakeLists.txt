#By default headers from `protocol`/`schema` are installed, therefore an installation should be blocked
SET( CUSTOM_INSTALLATION ON )

SET( target_name hfm-${HAF_GIT_REVISION_SHA} )

ADD_RUNTIME_LOADED_LIB( ${target_name} )



SET (SAVE_ORIGINAL_LIB_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES} )
SET (CMAKE_FIND_LIBRARY_SUFFIXES .so)
# using a new HAF_PQXX_LIB variable and not reusing PQXX_LIB variable because it is already set by the sql_serializer to static
FIND_LIBRARY(HAF_PQXX_LIB pqxx REQUIRED)
FIND_LIBRARY(HAF_PQ_LIB pq REQUIRED)
# restore
SET (CMAKE_FIND_LIBRARY_SUFFIXES ${SAVE_ORIGINAL_LIB_SUFFIXES} )


TARGET_LINK_LIBRARIES( ${target_name} PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})

find_package(PostgreSQL REQUIRED)
if(PostgreSQL_FOUND)
  message(STATUS "PostgreSQL found")
else()
  message(FATAL_ERROR "PostgreSQL not found")
endif()



ADD_RUNTIME_LOADED_EXE( mtlk_executable mtlk_main.cpp)

# mtlk conflict of -O0 and -O0 options
if(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    target_compile_options(mtlk_executable PRIVATE -O0)
endif()


# ADD_EXECUTABLE(mtlk_executable
    
#   mtlk_main.cpp
# )

SET_TARGET_PROPERTIES( mtlk_executable PROPERTIES EXCLUDE_FROM_ALL FALSE )


ADD_POSTGRES_INCLUDES( mtlk_executable )
ADD_POSTGRES_LIBRARIES( mtlk_executable )

find_library(POSTGRESQL_SERVER_LIBRARY
             NAMES postgres
             HINTS /usr/lib/postgresql/14/lib/postgres_fdw.so)
# if(NOT POSTGRESQL_SERVER_LIBRARY)
#   message(FATAL_ERROR "PostgreSQL server library not found")
# endif()
# target_link_libraries(your_target_name PRIVATE ${POSTGRESQL_SERVER_LIBRARY})

target_link_libraries(mtlk_executable
    PUBLIC  ${target_name} 
)

get_target_property(DEBUG_LIBS mtlk_executable LINK_LIBRARIES)
message(STATUS "Linked libraries: ${DEBUG_LIBS}")

get_target_property(DEBUG_LIBS ${target_name} LINK_LIBRARIES)
message(STATUS "Linked libraries: ${DEBUG_LIBS}")

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

