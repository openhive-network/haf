ADD_EXECUTABLE( consp_driver driver_main.cpp
../../shared_lib/consensus_state_provider_replay.cpp
../../shared_lib/consensus_state_provider_replay.hpp
)

SETUP_CLANG_TIDY( consp_driver )

TARGET_LINK_LIBRARIES(consp_driver PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})

# mtlk conflict of -O2 and -O0 options
if(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    target_compile_options(consp_driver PRIVATE -O0)
endif()

# get_target_property(DEBUG_LIBS consp_driver LINK_LIBRARIES)
# message(STATUS "Linked libraries: ${DEBUG_LIBS}")
