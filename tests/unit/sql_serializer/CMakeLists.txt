ADD_UNIT_TESTS( sql_serializer )

TARGET_INCLUDE_DIRECTORIES(
        ${test_target}
        PUBLIC
        "${CMAKE_SOURCE_DIR}/hive/libraries/protocol/include"
        "${CMAKE_BINARY_DIR}/hive/libraries/protocol/include"
        "${CMAKE_SOURCE_DIR}/hive/libraries/chain/include"
        "${CMAKE_SOURCE_DIR}/hive/libraries/utilities/include"
        "${CMAKE_SOURCE_DIR}/src/sql_serializer/include"
)

TARGET_LINK_LIBRARIES( ${test_target} PRIVATE sql_serializer_plugin )