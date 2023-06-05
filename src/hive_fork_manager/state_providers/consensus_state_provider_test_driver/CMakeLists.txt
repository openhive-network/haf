ADD_EXECUTABLE( mtlk_executable driver_main.cpp
../../shared_lib/consensus_state_provider_replay.cpp
../../shared_lib/consensus_state_provider_replay.hpp
../../shared_lib/pqxx_op_iterator.cpp
../../shared_lib/pqxx_op_iterator.hpp
)

SETUP_CLANG_TIDY( mtlk_executable )

TARGET_LINK_LIBRARIES(mtlk_executable PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})

# mtlk conflict of -O0 and -O0 options
if(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    target_compile_options(mtlk_executable PRIVATE -O0)
endif()

# get_target_property(DEBUG_LIBS mtlk_executable LINK_LIBRARIES)
# message(STATUS "Linked libraries: ${DEBUG_LIBS}")
