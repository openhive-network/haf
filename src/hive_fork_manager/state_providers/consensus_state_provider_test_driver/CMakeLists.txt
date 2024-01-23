ADD_EXECUTABLE( csp_driver conensus_state_provider_test_driver.cpp
../../shared_lib/consensus_state_provider_replay.cpp
../../shared_lib/consensus_state_provider_replay.hpp
)

SETUP_CLANG_TIDY( csp_driver )

# #define USE_PQXX
# TARGET_LINK_LIBRARIES(csp_driver PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})
TARGET_LINK_LIBRARIES(csp_driver PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin)

