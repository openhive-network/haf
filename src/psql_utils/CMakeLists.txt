SET( target_name psql_utils )

ADD_STATIC_LIB( TARGET_NAME ${target_name} LINK_WITH fc_pic )
set_target_properties( ${target_name} PROPERTIES POSITION_INDEPENDENT_CODE ON )
