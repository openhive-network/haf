SET( test_target test.system.haf )

IF ( BUILD_HIVE_TESTNET )
ADD_TEST( NAME ${test_target}
	COMMAND ${CMAKE_COMMAND} -E env
	PYTHONPATH=${CMAKE_SOURCE_DIR}/hive/tests/test_tools/package:${CMAKE_SOURCE_DIR}/tests/integration/local_tools
	HIVE_BUILD_ROOT_PATH=${CMAKE_BINARY_DIR}/hive
	tox .
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	)
MESSAGE( STATUS "Added system tests '${test_target}'" )
ELSE ( BUILD_HIVE_TESTNET )
    MESSAGE ( STATUS "haf system tests skipped: BUILD_HIVE_TESTNET is required" )
ENDIF ( BUILD_HIVE_TESTNET )

