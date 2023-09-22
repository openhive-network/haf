ADD_UNIT_TESTS( sharedlib )

TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/src/psql_utils/. )
TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/src/psql_utils/include )
TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/hive/libraries/fc/include )
TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/hive/libraries/protocol/include )
TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_BINARY_DIR}/hive/libraries/protocol/include )
TARGET_LINK_LIBRARIES( ${test_target} PRIVATE hive_protocol fc_shared_boost  )
TARGET_LINK_LIBRARIES( ${test_target} PRIVATE mock )