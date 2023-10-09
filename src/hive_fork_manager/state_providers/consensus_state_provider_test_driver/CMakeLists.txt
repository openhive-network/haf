ADD_EXECUTABLE( csp_driver main.cpp conensus_state_provider_test_driver.cpp
../../shared_lib/consensus_state_provider_replay.cpp
../../shared_lib/consensus_state_provider_replay.hpp
)

SETUP_CLANG_TIDY( csp_driver )

TARGET_LINK_LIBRARIES(csp_driver PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})

cmake_minimum_required(VERSION 3.10)
project(csp_driver_lib)

ADD_LIBRARY (csp_driver_lib SHARED  PostgreSQL_wrapper.cpp )

SETUP_COMPILER( csp_driver_lib )
SETUP_CLANG_TIDY( csp_driver_lib )

ADD_POSTGRES_INCLUDES( csp_driver_lib )
ADD_POSTGRES_LIBRARIES( csp_driver_lib )


# target_include_directories(csp_driver_lib PRIVATE ${PostgreSQL_INCLUDE_DIRS})
# target_link_libraries(csp_driver_lib ${PostgreSQL_LIBRARIES} ${HAF_PQ_LIB} ${HAF_PQXX_LIB})
TARGET_LINK_LIBRARIES(csp_driver_lib PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})

# TARGET_LINK_LIBRARIES(csp_driver_lib PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})


cmake_minimum_required(VERSION 3.10)
project(csp_driver_extension)

# find_package(PostgreSQL REQUIRED)

add_library(csp_driver_extension MODULE PostgreSQL_wrapper.cpp)
ADD_POSTGRES_INCLUDES( csp_driver_extension )
ADD_POSTGRES_LIBRARIES( csp_driver_extension )
# target_link_libraries(csp_driver_extension ${POSTGRES_LIBDIR})
TARGET_LINK_LIBRARIES(csp_driver_extension PUBLIC hive_protocol fc_shared_boost database_api_plugin block_api_plugin ${HAF_PQ_LIB} ${HAF_PQXX_LIB})
set_target_properties(csp_driver_extension PROPERTIES PREFIX "")

# install(TARGETS csp_driver_extension
#         DESTINATION ${POSTGRES_LIBDIR})

# install(FILES csp_driver_extension.control
#         DESTINATION ${POSTGRES_SHAREDIR}/extension/)

# install(FILES csp_driver_extension.sql
#         DESTINATION ${POSTGRES_SHAREDIR}/extension/)