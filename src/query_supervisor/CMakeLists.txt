SET( target_name query_supervisor )

ADD_RUNTIME_LOADED_LIB( ${target_name} )
TARGET_LINK_LIBRARIES( ${target_name} PRIVATE pq_utils psql_utils )

INSTALL( TARGETS ${target_name} DESTINATION ${POSTGRES_LIBDIR}/plugins OPTIONAL )