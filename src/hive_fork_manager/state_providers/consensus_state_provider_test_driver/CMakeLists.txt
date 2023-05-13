

ADD_EXECUTABLE( mtlk_executable /home/haf_admin/haf/src/hive_fork_manager/state_providers/driver_main.cpp
/home/haf_admin/haf/src/hive_fork_manager/shared_lib/consensus_state_provider_replay.cpp
/home/haf_admin/haf/src/hive_fork_manager/shared_lib/consensus_state_provider_replay.hpp)

# SETUP_COMPILER( mtlk_executable} )
SETUP_CLANG_TIDY( mtlk_executable )

ADD_POSTGRES_INCLUDES( mtlk_executable)
ADD_POSTGRES_LIBRARIES( mtlk_executable )


SET_TARGET_PROPERTIES( mtlk_executable PROPERTIES EXCLUDE_FROM_ALL FALSE )


ADD_POSTGRES_INCLUDES( mtlk_executable )
ADD_POSTGRES_LIBRARIES( mtlk_executable )


target_link_libraries(mtlk_executable
     PUBLIC 
     hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB}
)

get_target_property(DEBUG_LIBS mtlk_executable LINK_LIBRARIES)
message(STATUS "Linked libraries: ${DEBUG_LIBS}")

