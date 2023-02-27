ADD_UNIT_TESTS( query_supervisor )

TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/src/query_supervisor/. )
TARGET_LINK_LIBRARIES( ${test_target} PRIVATE mock )