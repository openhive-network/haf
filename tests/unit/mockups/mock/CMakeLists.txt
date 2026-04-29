SET( target_name mock )

ADD_RUNTIME_LOADED_LIB( TARGET_NAME ${target_name} )
ADD_DEPENDENCIES( ${target_name} googletest )

TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${CMAKE_SOURCE_DIR}/src/psql_utils/include )
TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${CMAKE_SOURCE_DIR}/src/pq_utils/include )
TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/googletest/googlemock/include )
TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/googletest/googletest/include )

FIND_PACKAGE( OpenSSL REQUIRED )
TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${OPENSSL_INCLUDE_DIR} )

FIND_PACKAGE( Boost REQUIRED )
TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${Boost_INCLUDE_DIRS} )
