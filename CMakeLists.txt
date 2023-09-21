CMAKE_MINIMUM_REQUIRED( VERSION 3.14 )

SET( CMAKE_POSITION_INDEPENDENT_CODE ON )
SET( CMAKE_CXX_STANDARD 17 )
SET( CMAKE_CXX_STANDARD_REQUIRED ON )

# Enable export of compile_commands.json in the build directory.
# This file is useful to see detailed compiler invocations.
# It is also set to "ON" in the hived project.
SET(CMAKE_EXPORT_COMPILE_COMMANDS "ON")

list( APPEND CMAKE_MODULE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/hive/cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/hive/libraries/fc/GitVersionGen" )

#This must be processed before first project or enable_language statement
INCLUDE(hive_build_types)

PROJECT( haf )

SET( HAF_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} )
FILE( CREATE_LINK ${CMAKE_CURRENT_SOURCE_DIR}/src/sql_serializer ${CMAKE_CURRENT_SOURCE_DIR}/hive/libraries/plugins/sql_serializer SYMBOLIC )

ADD_SUBDIRECTORY( hive EXCLUDE_FROM_ALL )

# Read whole HAF revision (using already imported Git tools from Hive project)
include( GetGitRevisionDescription )
get_git_head_revision_dir("${CMAKE_CURRENT_SOURCE_DIR}" HAF_GIT_REFSPEC HAF_GIT_REVISION_SHA)

MESSAGE(STATUS "Detected HAF project git revision: ${HAF_GIT_REVISION_SHA}")

SET_TARGET_PROPERTIES( hived PROPERTIES EXCLUDE_FROM_ALL 0 )
SET_TARGET_PROPERTIES( cli_wallet PROPERTIES EXCLUDE_FROM_ALL 0 )
SET_TARGET_PROPERTIES( get_dev_key PROPERTIES EXCLUDE_FROM_ALL 0 )
SET_TARGET_PROPERTIES( compress_block_log PROPERTIES EXCLUDE_FROM_ALL 0 )

IF ( NOT DEFINED POSTGRES_INSTALLATION_DIR )
    FIND_PROGRAM( POSTGRES_PG_CONFIG NAMES pg_config )
    IF ( POSTGRES_PG_CONFIG )
        EXECUTE_PROCESS(COMMAND ${POSTGRES_PG_CONFIG} --bindir OUTPUT_VARIABLE POSTGRES_INSTALLATION_DIR OUTPUT_STRIP_TRAILING_WHITESPACE)
    ELSE()
        SET( POSTGRES_INSTALLATION_DIR "/usr/lib/postgresql/14/bin" )
    ENDIF()
ENDIF()

SET( CMAKE_SKIP_INSTALL_ALL_DEPENDENCY TRUE )

INCLUDE( ExternalProject )

INCLUDE( hive_options )
INCLUDE( hive_targets )
INCLUDE( clangtidy )
INCLUDE( compiler )
INCLUDE( libraries )
INCLUDE( postgres )
INCLUDE( sql_extension )
INCLUDE( targets )
INCLUDE( tests )

SETUP_OUTPUT_DIRECTORIES()
GET_RUNTIME_POSTGRES_VARIABLES()

set(CMAKE_INSTALL_RPATH ${POSTGRES_LIBDIR})
SET(CMAKE_INSTALL_PREFIX ${POSTGRES_LIBDIR} CACHE PATH "DEFAULT PREFIX" FORCE)

ENABLE_TESTING()

ADD_SUBDIRECTORY( src )

ADD_SUBDIRECTORY( tests )
