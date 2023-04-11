MACRO(  ADD_SQL_FUNCTIONAL_TEST sql_test_path )
    GET_FILENAME_COMPONENT( test_dir ${sql_test_path} DIRECTORY )
    GET_FILENAME_COMPONENT( test_name  ${sql_test_path} NAME_WLE )
    SET( test_name ${test_dir}.${test_name})
    STRING( REPLACE "/" "." test_name ${test_name} )

    CMAKE_PATH( GET CMAKE_CURRENT_SOURCE_DIR FILENAME tests_folder  )
    SET( test_target test.functional.${tests_folder}.${test_name} )
    SET( sources_under_tests_path ${CMAKE_SOURCE_DIR}/src/${tests_folder} )
    SET( setup_scripts_dir_path ${PROJECT_SOURCE_DIR}/scripts/ )
    ADD_TEST( NAME ${test_target}
            COMMAND tools/test.sh ${sources_under_tests_path} ${tests_folder}/${sql_test_path} ${setup_scripts_dir_path} ${POSTGRES_PORT}
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/tests/integration/functional
            )
    MESSAGE( STATUS "Added a functional test '${test_target}'" )
ENDMACRO()

# hive_fork_manager functional tests are written only for the mainnet
IF ( NOT BUILD_HIVE_TESTNET )
    ADD_SUBDIRECTORY(hive_fork_manager)
    ADD_SUBDIRECTORY(query_supervisor)
ENDIF()