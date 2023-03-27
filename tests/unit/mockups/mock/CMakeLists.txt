SET( target_name mock )

ADD_RUNTIME_LOADED_LIB( ${target_name} )
ADD_DEPENDENCIES( ${target_name} googletest )

TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${CMAKE_SOURCE_DIR}/src/psql_utils/include )
TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${CMAKE_SOURCE_DIR}/src/pq_utils/include )
TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/googletest/googlemock/include )
TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/googletest/googletest/include )
