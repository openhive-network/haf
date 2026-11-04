SET( target_name "transaction_controllers")

ADD_STATIC_LIB( TARGET_NAME ${target_name} LINK_WITH appbase )

# Public sql_serializer headers include these, so their consumers need them on the include path.
TARGET_INCLUDE_DIRECTORIES( ${target_name} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include" )
TARGET_INCLUDE_DIRECTORIES( ${test_lib} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include" )
