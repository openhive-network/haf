MACRO( ADD_SQL_FUNCTIONAL_TESTS sql_test_path)
    STRING( REGEX MATCH "^(([^\\/]*)\\/)?(.*)\\.[^.]*$" dummy ${sql_test_path} ) # remove sql extension
    SET( test_name ${CMAKE_MATCH_3})
    IF( CMAKE_MATCH_2 )
        SET( test_name ${CMAKE_MATCH_2}.${test_name} )
    ENDIF()
    SET( test_target test.functional.hive_fork_manager.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/sql_fork_extension )
    SET( setup_scripts_dir_path ${PROJECT_SOURCE_DIR}/scripts/ )
    ADD_TEST( NAME ${test_target}
            COMMAND test.sh ${sources_under_tests_path} ${sql_test_path} ${setup_scripts_dir_path} ${POSTGRES_PORT}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            )
    MESSAGE( STATUS "Added functional tests '${test_target}'" )
ENDMACRO()

MACRO( ADD_AUTHORIZATION_FUNCTIONAL_TESTS sql_test_path)
    STRING( REGEX MATCH "^(([^\\/]*)\\/)?(.*)\\.[^.]*$" dummy ${sql_test_path} ) # remove sql extension
    SET( test_name ${CMAKE_MATCH_3})
    IF( CMAKE_MATCH_2 )
        SET( test_name ${CMAKE_MATCH_2}.${test_name} )
    ENDIF()
    SET( test_target test.functional.hive_fork_manager.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/hive_fork_manager )
    ADD_TEST( NAME ${test_target}
            COMMAND test_authorization.sh ${sources_under_tests_path} ${sql_test_path} ${setup_scripts_dir_path} ${POSTGRES_PORT}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            )
    MESSAGE( STATUS "Added functional authorization tests '${test_target}'" )
ENDMACRO()

MACRO( ADD_EXAMPLES_FUNCTIONAL_TESTS example_test_path)
    STRING( REGEX MATCH "^(([^\\/]*)\\/)?(.*)\\.[^.]*$" dummy ${example_test_path} ) # remove py extension
    SET( test_name ${CMAKE_MATCH_3})
    IF( CMAKE_MATCH_2 )
        SET( test_name ${CMAKE_MATCH_2}.${test_name} )
    ENDIF()
    SET( test_target test.functional.hive_fork_manager.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/hive_fork_manager/doc/examples )
    ADD_TEST( NAME ${test_target}
            COMMAND test_examples.sh ${sources_under_tests_path} ${example_test_path} ${setup_scripts_dir_path} ${POSTGRES_PORT}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            )
    MESSAGE( STATUS "Added functional authorization tests '${test_target}'" )
ENDMACRO()


# hive_fork_manager functional tests are written only for the mainnet
IF ( NOT BUILD_HIVE_TESTNET )
    ADD_SUBDIRECTORY(hive_fork_manager)
ENDIF()