add_executable( op_body_filter op_body_filter.cpp )

target_link_libraries( op_body_filter
                       PRIVATE sql_serializer_plugin hive_protocol fc ${CMAKE_DL_LIBS} ${PLATFORM_SPECIFIC_LIBS} )
