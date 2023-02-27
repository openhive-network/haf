ADD_UNIT_TESTS( pq_utils )

TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/src/pq_utils/. )
TARGET_LINK_LIBRARIES( ${test_target} PRIVATE mock )