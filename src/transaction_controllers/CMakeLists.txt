SET( target_name "transaction_controllers")

ADD_STATIC_LIB( TARGET_NAME ${target_name} LINK_WITH appbase )

FIND_PATH( PQXX_INCLUDE_DIR NAMES pqxx/pqxx REQUIRED )
target_include_directories( ${target_name} PUBLIC ${PQXX_INCLUDE_DIR} )
target_include_directories( test_${target_name} PUBLIC ${PQXX_INCLUDE_DIR} )
