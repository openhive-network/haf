MACRO( ADD_PSQL_EXTENSION )
set(multiValueArgs DEPLOY_SOURCES SCHEMA_SOURCES)
set(OPTIONS "")
set(oneValueArgs NAME )

CMAKE_PARSE_ARGUMENTS( EXTENSION "${OPTIONS}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

MESSAGE( STATUS "EXTENSION_NAME: ${EXTENSION_NAME}" )

SET( extension_path  "${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME}" )

FILE( MAKE_DIRECTORY "${extension_path}" )

SET(HAF_GIT_REVISION_SHA "e733be375a203cacaaf3da6766347e9e053f3f44" )
message(STATUS "mtlk Variable HAF_GIT_REVISION_SHA value: ${HAF_GIT_REVISION_SHA}")

SET( UPDATE_NAME "${EXTENSION_NAME}_update--${HAF_GIT_REVISION_SHA}" )

SET( update_control_script ${UPDATE_NAME}.sql )

SET( extension_control_file ${EXTENSION_NAME}.control.in )

SET( extension_control_script ${EXTENSION_NAME}--${HAF_GIT_REVISION_SHA}.sql )

FILE(WRITE ${extension_path}/${update_control_script} "")

FILE(WRITE ${extension_path}/${extension_control_script} "")

SET( temp_deploy_sources deploy_sources.sql )

SET( temp_schema_sources schema_sources.sql )

MESSAGE( STATUS "VERSION: ${HAF_GIT_REVISION_SHA}" )

#MESSAGE( STATUS "EXTENSION_SCHEMA_SOURCES: ${EXTENSION_SCHEMA_SOURCES}")
#MESSAGE( STATUS "EXTENSION_DEPLOY_SOURCES: ${EXTENSION_DEPLOY_SOURCES}")

#cat function
FUNCTION(cat IN_FILE OUT_FILE)
FILE(READ ${IN_FILE} CONTENTS)
FILE(APPEND ${OUT_FILE} "${CONTENTS}")
ENDFUNCTION()

#concatination of deploy_sources.sql
FOREACH(EXTENSION_DEPLOY_SOURCES ${EXTENSION_DEPLOY_SOURCES})
cat(${EXTENSION_DEPLOY_SOURCES} ${extension_path}/${temp_deploy_sources})
ENDFOREACH()

CONFIGURE_FILE( "${extension_path}/deploy_sources.sql" "${extension_path}/${update_control_script}")

FILE (REMOVE ${extension_path}/${temp_deploy_sources})

#append table schema and function lists
LIST(APPEND EXTENSION_SCHEMA_SOURCES ${EXTENSION_DEPLOY_SOURCES})

#concatination of schema_sources.sql
FOREACH(EXTENSION_SCHEMA_SOURCES ${EXTENSION_SCHEMA_SOURCES})
cat(${EXTENSION_SCHEMA_SOURCES} ${extension_path}/${temp_schema_sources})
ENDFOREACH()

CONFIGURE_FILE( "${extension_path}/schema_sources.sql" "${extension_path}/${extension_control_script}")

FILE (REMOVE ${extension_path}/${temp_schema_sources})

MESSAGE( STATUS "CONFIGURING the update script generator script: ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME}/hive_fork_manager_update_script_generator.sh" )

CONFIGURE_FILE( "${CMAKE_CURRENT_SOURCE_DIR}/hive_fork_manager_update_script_generator.sh.in"
  "${extension_path}/hive_fork_manager_update_script_generator.sh" @ONLY)

MESSAGE( STATUS "CONFIGURING the control file: ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME}/hive_fork_manager.control" )

CONFIGURE_FILE( "${CMAKE_CURRENT_SOURCE_DIR}/${extension_control_file}"
  "${extension_path}/hive_fork_manager.control" @ONLY)

ADD_CUSTOM_COMMAND(
        OUTPUT  "${extension_path}/${extension_control_file}" "${extension_path}/${extension_control_script}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS ${EXTENSION_DEPLOY_SOURCES} ${EXTENSION_SCHEMA_SOURCES} ${extension_control_file}
        COMMENT "Generating ${EXTENSION_NAME} files to ${extension_path}"
)

ADD_CUSTOM_COMMAND(
        OUTPUT "${extension_path}/${update_control_script}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS ${EXTENSION_DEPLOY_SOURCES}
        COMMENT "Generating ${EXTENSION_NAME} helper update scripts to ${update_path}, final upgrade script: ${extension_path}/${update_control_script}"
)

ADD_CUSTOM_TARGET( extension.${EXTENSION_NAME} ALL DEPENDS ${extension_path}/${extension_control_file} ${extension_path}/${extension_control_script} ${extension_path}/${update_control_script} )

INSTALL ( FILES "${extension_path}/hive_fork_manager_update_script_generator.sh"
          DESTINATION ${POSTGRES_SHAREDIR}/extension
          PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
          GROUP_EXECUTE GROUP_READ
          WORLD_EXECUTE WORLD_READ
        )
INSTALL ( FILES "${extension_path}/${update_control_script}" "${extension_path}/${EXTENSION_NAME}.control" "${extension_path}/${extension_control_script}"
          DESTINATION ${POSTGRES_SHAREDIR}/extension
          PERMISSIONS OWNER_WRITE OWNER_READ
          GROUP_READ
          WORLD_READ
        )

ENDMACRO()

