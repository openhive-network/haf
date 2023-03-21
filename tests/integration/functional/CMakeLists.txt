MACRO( ADD_SQL_FUNCTIONAL_TESTS_TYPE_FOR_LIBRARY sql_test_path preloaded_library test_script_type) # test_script_type gwt or error
    GET_FILENAME_COMPONENT( test_dir ${sql_test_path} DIRECTORY )
    GET_FILENAME_COMPONENT( test_name  ${sql_test_path} NAME_WLE )
    SET( test_name ${test_dir}.${test_name})
    STRING( REPLACE "/" "." test_name ${test_name} )

    CMAKE_PATH( GET CMAKE_CURRENT_SOURCE_DIR FILENAME tests_folder  )
    SET( test_target test.functional.${tests_folder}.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/${tests_folder} )
    SET( setup_scripts_dir_path ${PROJECT_SOURCE_DIR}/scripts/ )
    ADD_TEST( NAME ${test_target}
            COMMAND tools/test_${test_script_type}.sh ${sources_under_tests_path} ${tests_folder}/${sql_test_path} ${setup_scripts_dir_path} ${POSTGRES_PORT} ${preloaded_library}
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/tests/integration/functional
            )
    MESSAGE( STATUS "Added functional tests '${test_target}'" )
ENDMACRO()

MACRO( ADD_SQL_ERROR_FUNCTIONAL_TESTS_FOR_LIBRARY sql_test_path preloaded_library )
    ADD_SQL_FUNCTIONAL_TESTS_TYPE_FOR_LIBRARY( ${sql_test_path} ${preloaded_library} error )
ENDMACRO()

MACRO( ADD_SQL_FUNCTIONAL_TESTS sql_test_path preloaded_library)
    ADD_SQL_FUNCTIONAL_TESTS_TYPE_FOR_LIBRARY( ${sql_test_path} ${preloaded_library} gwt )
ENDMACRO()

MACRO( ADD_SQL_FUNCTIONAL_TESTS sql_test_path )
    ADD_SQL_FUNCTIONAL_TESTS_TYPE_FOR_LIBRARY( ${sql_test_path} "" gwt )
ENDMACRO()

MACRO( ADD_AUTHORIZATION_FUNCTIONAL_TESTS_TYPE_FOR_LIBRARY sql_test_path preloaded_library test_script_type)
    GET_FILENAME_COMPONENT( test_dir ${sql_test_path} DIRECTORY )
    GET_FILENAME_COMPONENT( test_name  ${sql_test_path} NAME_WLE )
    SET( test_name ${test_dir}.${test_name})
    STRING( REPLACE "/" "." test_name ${test_name} )

    CMAKE_PATH( GET CMAKE_CURRENT_SOURCE_DIR FILENAME tests_folder  )
    SET( test_target test.functional.${tests_folder}.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/${tests_folder} )
    ADD_TEST( NAME ${test_target}
            COMMAND tools/test_authorization_${test_script_type}.sh ${sources_under_tests_path} ${tests_folder}/${sql_test_path} ${setup_scripts_dir_path} ${POSTGRES_PORT} ${preloaded_library}
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/tests/integration/functional
            )
    MESSAGE( STATUS "Added functional authorization tests '${test_target}'" )
ENDMACRO()

MACRO( ADD_AUTHORIZATION_FUNCTIONAL_TESTS sql_test_path)
    ADD_AUTHORIZATION_FUNCTIONAL_TESTS_TYPE_FOR_LIBRARY( ${sql_test_path} "" gwt )
ENDMACRO()

MACRO( ADD_AUTHORIZATION_ERROR_FUNCTIONAL_TESTS sql_test_path preloaded_library )
    ADD_AUTHORIZATION_FUNCTIONAL_TESTS_TYPE_FOR_LIBRARY( ${sql_test_path} ${preloaded_library} error )
ENDMACRO()

# hive_fork_manager functional tests are written only for the mainnet
IF ( NOT BUILD_HIVE_TESTNET )
    ADD_SUBDIRECTORY(hive_fork_manager)
    ADD_SUBDIRECTORY(query_supervisor)
ENDIF()