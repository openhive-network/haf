ADD_UNIT_TESTS( psql_utils )

TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/src/psql_utils/. )
TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/src/psql_utils/include )
TARGET_LINK_LIBRARIES( ${test_target} PRIVATE mock )