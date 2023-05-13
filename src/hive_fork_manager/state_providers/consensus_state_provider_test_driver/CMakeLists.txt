ADD_EXECUTABLE( mtlk_executable driver_main.cpp
../../shared_lib/consensus_state_provider_replay.cpp
../../shared_lib/consensus_state_provider_replay.hpp)

SETUP_CLANG_TIDY( mtlk_executable )

TARGET_LINK_LIBRARIES(mtlk_executable PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})
