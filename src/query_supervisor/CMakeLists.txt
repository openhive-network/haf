SET( target_name query_supervisor )

ADD_RUNTIME_LOADED_LIB( TARGET_NAME ${target_name} LINK_WITH pq_utils psql_utils )

INSTALL( TARGETS ${target_name} DESTINATION ${POSTGRES_PKGLIBDIR} OPTIONAL )