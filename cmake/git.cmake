MACRO( GENERATE_GIT_VERSION_FILE )
    SET( GIT_REVISION "unknown" )

    FIND_PACKAGE(Git)
    IF ( GIT_FOUND )
        EXECUTE_PROCESS(
                COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
                WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                OUTPUT_VARIABLE GIT_REVISION
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        MESSAGE( STATUS "GIT hash: ${GIT_REVISION}" )
    else()
        MESSAGE( STATUS "GIT not found" )
    endif()

    CONFIGURE_FILE( ${CMAKE_MODULE_PATH}/git_version.hpp.in ${GENERATED_FILES_DIRECTORY}/git_version.hpp @ONLY )
ENDMACRO()