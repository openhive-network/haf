MACRO( ADD_SQL_FUNCTIONAL_TESTS sql_test_path)
    STRING( REGEX MATCH "^(([^\\/]*)\\/)?(.*)\\.[^.]*$" dummy ${sql_test_path} ) # remove sql extension
    SET( test_name ${CMAKE_MATCH_3})
    IF( CMAKE_MATCH_2 )
        SET( test_name ${CMAKE_MATCH_2}.${test_name} )
    ENDIF()
    CMAKE_PATH( GET CMAKE_CURRENT_SOURCE_DIR FILENAME tests_folder  )
    SET( test_target test.functional.${tests_folder}.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/${tests_folder} )
    SET( setup_scripts_dir_path ${PROJECT_SOURCE_DIR}/scripts/ )
    ADD_TEST( NAME ${test_target}
            COMMAND tools/test.sh ${sources_under_tests_path} ${tests_folder}/${sql_test_path} ${setup_scripts_dir_path} ${POSTGRES_PORT}
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/tests/integration/functional
            )
    MESSAGE( STATUS "Added functional tests '${test_target}'" )
ENDMACRO()

MACRO( ADD_AUTHORIZATION_FUNCTIONAL_TESTS sql_test_path)
    STRING( REGEX MATCH "^(([^\\/]*)\\/)?(.*)\\.[^.]*$" dummy ${sql_test_path} ) # remove sql extension
    SET( test_name ${CMAKE_MATCH_3})
    IF( CMAKE_MATCH_2 )
        SET( test_name ${CMAKE_MATCH_2}.${test_name} )
    ENDIF()
    CMAKE_PATH( GET CMAKE_CURRENT_SOURCE_DIR FILENAME tests_folder  )
    SET( test_target test.functional.${tests_folder}.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/${tests_folder} )
    ADD_TEST( NAME ${test_target}
            COMMAND tools/test_authorization.sh ${sources_under_tests_path} ${tests_folder}/${sql_test_path} ${setup_scripts_dir_path} ${POSTGRES_PORT}
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/tests/integration/functional
            )
    MESSAGE( STATUS "Added functional authorization tests '${test_target}'" )
ENDMACRO()

# hive_fork_manager functional tests are written only for the mainnet
IF ( NOT BUILD_HIVE_TESTNET )
    ADD_SUBDIRECTORY(hive_fork_manager)
    ADD_SUBDIRECTORY(query_supervisor)
ENDIF()