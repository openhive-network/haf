file(GLOB HEADERS "include/hive/plugins/sql_serializer/*.hpp")

FIND_LIBRARY(PQXX_LIB pqxx)
FIND_LIBRARY(PQ_LIB pq)

ADD_LIBRARY(
    sql_serializer_plugin
    sql_serializer.cpp
    data_processor.cpp
    end_massive_sync_processor.cpp
    block_num_rendezvous_trigger.cpp
    data_2_sql_tuple_base.cpp
    reindex_data_dumper.cpp
    tables_descriptions.cpp
    livesync_data_dumper.cpp
    queries_commit_data_processor.cpp
    string_data_processor.cpp
    indexation_state.cpp
    accounts_collector.cpp
    ${HEADERS}
)

target_link_libraries( sql_serializer_plugin chain_plugin hive_chain hive_protocol transaction_controllers ${PQXX_LIB} )

target_include_directories(
    sql_serializer_plugin
    PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include"
    PRIVATE "${PostgreSQL_INCLUDE_DIRS}" "${HAF_DIRECTORY}/common_includes/include"
)

if( CLANG_TIDY_EXE )
   set_target_properties(
      sql_serializer_plugin PROPERTIES
      CXX_CLANG_TIDY "${DO_CLANG_TIDY}"
   )
endif( CLANG_TIDY_EXE )

install( TARGETS
    sql_serializer_plugin

    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)
