CMAKE_MINIMUM_REQUIRED( VERSION 3.14 )

SET( CMAKE_POSITION_INDEPENDENT_CODE ON )
SET( CMAKE_CXX_STANDARD 17 )
SET( CMAKE_CXX_STANDARD_REQUIRED ON )

# Compiler caching support (sccache preferred, ccache fallback)
find_program(SCCACHE_PROGRAM sccache)
find_program(CCACHE_PROGRAM ccache)

if(SCCACHE_PROGRAM)
  message(STATUS "Found sccache: ${SCCACHE_PROGRAM}")
  set(CMAKE_C_COMPILER_LAUNCHER "${SCCACHE_PROGRAM}")
  set(CMAKE_CXX_COMPILER_LAUNCHER "${SCCACHE_PROGRAM}")
elseif(CCACHE_PROGRAM)
  message(STATUS "Found ccache: ${CCACHE_PROGRAM}")
  set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
  set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
endif()

list( APPEND CMAKE_MODULE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/hive/cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/hive/libraries/fc/GitVersionGen" )

#This must be processed before first project or enable_language statement
INCLUDE(hive_build_types)

PROJECT( haf )

SET( HAF_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} )

# Create symlink for sql_serializer plugin
# Handles CI edge cases: broken symlinks, stale symlinks, missing parent directories
SET( SQL_SERIALIZER_LINK ${CMAKE_CURRENT_SOURCE_DIR}/hive/libraries/plugins/sql_serializer )
SET( SQL_SERIALIZER_TARGET ${CMAKE_CURRENT_SOURCE_DIR}/src/sql_serializer )

# Check if symlink already exists and points to correct target (fast path)
set(symlink_needs_update TRUE)
if(IS_SYMLINK ${SQL_SERIALIZER_LINK})
    file(READ_SYMLINK ${SQL_SERIALIZER_LINK} existing_target)
    if(existing_target STREQUAL SQL_SERIALIZER_TARGET)
        set(symlink_needs_update FALSE)
    endif()
endif()

if(symlink_needs_update)
    # Get parent directory and ensure it exists
    get_filename_component(SQL_SERIALIZER_LINK_DIR ${SQL_SERIALIZER_LINK} DIRECTORY)
    file(MAKE_DIRECTORY ${SQL_SERIALIZER_LINK_DIR})
    # Remove any existing file/symlink and create fresh symlink
    file(REMOVE ${SQL_SERIALIZER_LINK})
    file(CREATE_LINK ${SQL_SERIALIZER_TARGET} ${SQL_SERIALIZER_LINK} SYMBOLIC)
endif()

list( APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" )

INCLUDE( compiler )

if( "${CMAKE_GENERATOR}" STREQUAL "Ninja" )
    ENABLE_NINJA_COLORFUL_OUTPUT()
endif()

ADD_SUBDIRECTORY( hive EXCLUDE_FROM_ALL )

# Read whole HAF revision (using already imported Git tools from Hive project)
include( GetGitRevisionDescription )
get_git_head_revision_dir("${CMAKE_CURRENT_SOURCE_DIR}" HAF_GIT_REFSPEC HAF_GIT_REVISION_SHA)

MESSAGE(STATUS "Detected HAF project git revision: ${HAF_GIT_REVISION_SHA}")

SET_TARGET_PROPERTIES( hived PROPERTIES EXCLUDE_FROM_ALL 0 )
SET_TARGET_PROPERTIES( cli_wallet PROPERTIES EXCLUDE_FROM_ALL 0 )
SET_TARGET_PROPERTIES( get_dev_key PROPERTIES EXCLUDE_FROM_ALL 0 )
SET_TARGET_PROPERTIES( compress_block_log PROPERTIES EXCLUDE_FROM_ALL 0 )
SET_TARGET_PROPERTIES( block_log_util PROPERTIES EXCLUDE_FROM_ALL 0 )

IF( NOT HIVE_CONVERTER_BUILD )
    MESSAGE(AUTHOR_WARNING "Building without hive converter")
ELSE()
    SET_TARGET_PROPERTIES( blockchain_converter PROPERTIES EXCLUDE_FROM_ALL 0 )
ENDIF()

IF ( NOT DEFINED POSTGRES_INSTALLATION_DIR )
    FIND_PROGRAM( POSTGRES_PG_CONFIG NAMES pg_config )
    IF ( POSTGRES_PG_CONFIG )
        EXECUTE_PROCESS(COMMAND ${POSTGRES_PG_CONFIG} --bindir OUTPUT_VARIABLE POSTGRES_INSTALLATION_DIR OUTPUT_STRIP_TRAILING_WHITESPACE)
    ELSE()
        IF ( DEFINED ENV{POSTGRES_VERSION} )
            SET( POSTGRES_INSTALLATION_DIR "/usr/lib/postgresql/$ENV{POSTGRES_VERSION}/bin" )
        ELSE()
            SET( POSTGRES_INSTALLATION_DIR "/usr/lib/postgresql/17/bin" )
        ENDIF()
    ENDIF()
ENDIF()

SET( CMAKE_SKIP_INSTALL_ALL_DEPENDENCY TRUE )

INCLUDE( ExternalProject )

INCLUDE( hive_options )
INCLUDE( hive_targets )
INCLUDE( clangtidy )
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
