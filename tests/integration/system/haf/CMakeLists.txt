SET( test_target test.system.haf )

ADD_TEST( NAME ${test_target}
        COMMAND ${CMAKE_COMMAND} -E env
        PYTHONPATH=${CMAKE_SOURCE_DIR}/hive/tests/test_tools/package
        HIVE_BUILD_ROOT_PATH=${CMAKE_BINARY_DIR}/hive
        tox
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        )
MESSAGE( STATUS "Added system tests '${test_target}'" )