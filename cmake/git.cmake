MACRO( GENERATE_GIT_VERSION_FILE )
    FIND_PACKAGE(Git)
    IF ( GIT_FOUND )
        EXECUTE_PROCESS(
                COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
                WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                OUTPUT_VARIABLE GIT_REVISION
                RESULT_VARIABLE GIT_STATUS
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        if ( ${GIT_STATUS} AND NOT ${GIT_STATUS} EQUAL 0 )
          message( FATAL_ERROR "GIT command resulted with error code: ${GIT_STATUS}" )
        endif()

        IF ( "${GIT_REVISION}" STREQUAL "" )
            MESSAGE( FATAL_ERROR "GIT hash could not be retrieved" )
        endif()

        MESSAGE( STATUS "GIT hash: ${GIT_REVISION}" )
    else()
        MESSAGE( FATAL_ERROR "GIT not found" )
    endif()

    CONFIGURE_FILE( ${CMAKE_MODULE_PATH}/git_version.hpp.in ${GENERATED_FILES_DIRECTORY}/git_version.hpp @ONLY )
ENDMACRO()