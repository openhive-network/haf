# Sets:
# POSTGRES_LIBDIR - libdir
MACRO( GET_RUNTIME_POSTGRES_VARIABLES )
    SET( POSTGRES_VERSION "NOTFOUND" ) # only integer number: example 12 instead of 12.8
    SET( POSTGRES_LIBDIR "NOTFOUND" )
    SET( POSTGRES_SHAREDIR "NOTFOUND" )
    SET( SERVER_INCLUDE_LIST_DIR "NOTFOUND" )
    SET( POSTGRES_PORT "NOTFOUND" )

    EXECUTE_PROCESS(
            COMMAND ${POSTGRES_INSTALLATION_DIR}/pg_config --version
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE POSTGRES_VERSION
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    STRING( REPLACE " " ";" POSTGRES_VERSION ${POSTGRES_VERSION} )
    LIST( GET POSTGRES_VERSION 1 POSTGRES_VERSION )
    STRING( REGEX REPLACE "\\..+" "" POSTGRES_VERSION ${POSTGRES_VERSION} )

    EXECUTE_PROCESS(
            COMMAND ${POSTGRES_INSTALLATION_DIR}/pg_config --pkglibdir
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE POSTGRES_LIBDIR
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    EXECUTE_PROCESS(
            COMMAND ${POSTGRES_INSTALLATION_DIR}/pg_config --sharedir
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE POSTGRES_SHAREDIR
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    EXECUTE_PROCESS(
            COMMAND ${POSTGRES_INSTALLATION_DIR}/pg_config --includedir
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE SERVER_INCLUDE_LIST_DIR
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    EXECUTE_PROCESS(
            COMMAND ${POSTGRES_INSTALLATION_DIR}/pg_config --includedir-server
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE SERVER_INCLUDE_DIR
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    LIST( APPEND SERVER_INCLUDE_LIST_DIR ${SERVER_INCLUDE_DIR} )

    EXECUTE_PROCESS(
            COMMAND /bin/bash ${PROJECT_SOURCE_DIR}/scripts/get_postgres_port.sh ${POSTGRES_VERSION}
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE POSTGRES_PORT
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    MESSAGE( STATUS "Postgres version: ${POSTGRES_VERSION}" )
    MESSAGE( STATUS "Postgres libdir: ${POSTGRES_LIBDIR}" )
    MESSAGE( STATUS "Postgres sharedir: ${POSTGRES_SHAREDIR}" )
    MESSAGE( STATUS "Postgres server include dirs: ${SERVER_INCLUDE_LIST_DIR}" )
    MESSAGE( STATUS "Postgres server port: ${POSTGRES_PORT}" )

    IF ( NOT POSTGRES_LIBDIR )
        MESSAGE( FATAL_ERROR "Unknown postgres libdir" )
    ENDIF()

    IF ( NOT POSTGRES_SHAREDIR )
        MESSAGE( FATAL_ERROR "Unknown postgres shareddir" )
    ENDIF()

    IF ( NOT SERVER_INCLUDE_DIR )
        MESSAGE( FATAL_ERROR "Unknown postgres include dir" )
    ENDIF()

    IF ( NOT POSTGRES_PORT )
        MESSAGE( FATAL_ERROR "Unknown postgres port" )
    ENDIF()

ENDMACRO()