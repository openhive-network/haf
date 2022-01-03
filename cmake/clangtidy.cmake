MACRO( SETUP_CLANG_TIDY target_name )
    IF ( HIVE_LINT )
        SET( CLANG_TIDY_IGNORED
                "-cert-err09-cpp\
                ,-bugprone-lambda-function-name\
                ,-misc-throw-by-value-catch-by-reference\
                ,-cert-err61-cpp\
                ,-bugprone-exception-escape\
                ,-bugprone-unused-return-value\
                ,-hicpp-special-member-functions\
                ,-cert-err60-cpp\
                ,-hicpp-exception-baseclass\
                ,-hicpp-no-array-decay\
                ,-google-runtime-references\
                ,-modernize-use-trailing-return-type\
                ,-fuchsia-default-arguments\
                ,-fuchsia-default-arguments-calls\
                ,-hicpp-vararg\
                ,-llvm-include-order\
                ,-cppcoreguidelines-*\
                ,-google-readability-casting\
                ,-readability-redundant-access-specifiers\
                ,-misc-lambda-function-name\
                ,-readability-inconsistent-declaration-parameter-name\
                ,-google-runtime-int"
        )

        IF ( NOT CLANG_TIDY_EXE )
            MESSAGE( FATAL_ERROR  "Clang tidy tool is not found, but is required by enabled HIVE_LINT option")
        ENDIF()

        EXECUTE_PROCESS(
                COMMAND ${CLANG_TIDY_EXE} --version
                OUTPUT_VARIABLE CLANG_VERSION
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        STRING( REPLACE "\n" ";" CLANG_VERSION ${CLANG_VERSION} )
        LIST( GET CLANG_VERSION 1 CLANG_VERSION )
        STRING( REGEX MATCH "[0-9]+" CLANG_VERSION ${CLANG_VERSION} )

        SET( CLANG_ALL_CHECKS "--checks=*" )
        IF ( CLANG_VERSION LESS 10 )
            SET( CLANG_ALL_CHECKS "-checks=*" )
        ENDIF()

        MESSAGE( STATUS "Linting with clang-tidy v.${CLANG_VERSION} enabled for target ${target_name}" )
        SET( CLANG_TIDY_CMD_LINE ${CLANG_TIDY_EXE};${CLANG_ALL_CHECKS},${CLANG_TIDY_IGNORED};--warnings-as-errors=* )
        SET_TARGET_PROPERTIES( ${target_name} PROPERTIES CXX_CLANG_TIDY "${CLANG_TIDY_CMD_LINE}" )
    ENDIF()

ENDMACRO()