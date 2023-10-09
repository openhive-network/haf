
SET( target_name csp_driver )
message(STATUS "a target_name=${target_name}")

# ADD_EXECUTABLE( csp_driver conensus_state_provider_test_driver.cpp
# ../../shared_lib/consensus_state_provider_replay.cpp
# ../../shared_lib/consensus_state_provider_replay.hpp
# )

# ADD_RUNTIME_LOADED_LIB( TARGET_NAME csp_driver LINK_WITH hive_protocol fc_shared_boost )

# LIBRARIES_PARAMETERS( ${ARGV} )
message(STATUS "b target_name=${target_name}")
# FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )


ADD_LIBRARY( ${target_name} SHARED
conensus_state_provider_test_driver.cpp
../../shared_lib/consensus_state_provider_replay.cpp
../../shared_lib/consensus_state_provider_replay.hpp
 )



SETUP_CLANG_TIDY( "${target_name}" )

ADD_POSTGRES_INCLUDES( "${target_name}" )
ADD_POSTGRES_LIBRARIES( "${target_name}" )

# TARGET_LINK_LIBRARIES( "${target_name}" PUBLIC ${LIBRARY_LINK_WITH} )



TARGET_LINK_LIBRARIES(csp_driver PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin)

