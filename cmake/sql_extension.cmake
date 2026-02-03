MACRO( ADD_PSQL_EXTENSION )
set(multiValueArgs DEPLOY_SOURCES SCHEMA_SOURCES)
set(OPTIONS "")
set(oneValueArgs NAME )

CMAKE_PARSE_ARGUMENTS( EXTENSION "${OPTIONS}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

MESSAGE( STATUS "EXTENSION_NAME: ${EXTENSION_NAME}" )

SET( extension_path  "${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME}" )

FILE( MAKE_DIRECTORY "${extension_path}" )

SET( UPDATE_NAME "${EXTENSION_NAME}_update--${HAF_GIT_REVISION_SHA}" )

SET( update_control_script ${UPDATE_NAME}.sql )

SET( extension_control_file ${EXTENSION_NAME}.control.in )

SET( extension_control_script ${EXTENSION_NAME}--${HAF_GIT_REVISION_SHA}.sql )

# Note: Do NOT pre-create empty files here with FILE(WRITE).
# The custom commands below will create them at build time.
# Pre-creating empty files causes issues when reconfiguring - the empty file
# may have a newer timestamp than sources, causing ninja to skip regeneration.

SET( temp_deploy_sources deploy_sources.sql )

SET( temp_schema_sources schema_sources.sql )

MESSAGE( STATUS "VERSION: ${HAF_GIT_REVISION_SHA}" )

#MESSAGE( STATUS "EXTENSION_SCHEMA_SOURCES: ${EXTENSION_SCHEMA_SOURCES}")
#MESSAGE( STATUS "EXTENSION_DEPLOY_SOURCES: ${EXTENSION_DEPLOY_SOURCES}")

#append table schema and function lists
LIST(APPEND EXTENSION_SCHEMA_SOURCES ${EXTENSION_DEPLOY_SOURCES})

# Convert lists to semicolon-separated strings for passing to script
string(REPLACE ";" "\;" DEPLOY_SOURCES_STR "${EXTENSION_DEPLOY_SOURCES}")
string(REPLACE ";" "\;" SCHEMA_SOURCES_STR "${EXTENSION_SCHEMA_SOURCES}")

# Create header file for update script at configure time
FILE(WRITE "${extension_path}/.update_header.sql" "DO $$ BEGIN RAISE WARNING 'Extension is being updated'; END $$;\nDROP SCHEMA IF EXISTS hive CASCADE;\nCREATE SCHEMA hive;\n")

MESSAGE( STATUS "CONFIGURING the update script generator script: ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME}/hive_fork_manager_update_script_generator.sh" )

CONFIGURE_FILE( "${CMAKE_CURRENT_SOURCE_DIR}/hive_fork_manager_update_script_generator.sh.in"
  "${extension_path}/hive_fork_manager_update_script_generator.sh" @ONLY)

# Only needed to be able to run update script from ${CMAKE_CURRENT_SOURCE_DIR} dir
CONFIGURE_FILE( "${CMAKE_CURRENT_SOURCE_DIR}/update.sql"
        "${extension_path}/update.sql" @ONLY)

MESSAGE( STATUS "CONFIGURING the control file: ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME}/hive_fork_manager.control" )

CONFIGURE_FILE( "${CMAKE_CURRENT_SOURCE_DIR}/${extension_control_file}"
  "${extension_path}/hive_fork_manager.control" @ONLY)

# concatenation of deploy_sources.sql
# all objects in schema hive can be dropped and then recreated
# all objects in schema hafd cannot be updated and full resync of HAF is required in case of changes there
# first we need to drop schema hive, thus to avoid annoying problem with ambiguity when a function
# change list of their parameters and its old version was not removed
ADD_CUSTOM_COMMAND(
        OUTPUT "${extension_path}/${update_control_script}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} -E cat "${extension_path}/.update_header.sql" ${EXTENSION_DEPLOY_SOURCES} > "${extension_path}/${update_control_script}"
        DEPENDS ${EXTENSION_DEPLOY_SOURCES}
        COMMENT "Generating ${EXTENSION_NAME} update script to ${extension_path}/${update_control_script}"
)

# concatination of schema_sources.sql
ADD_CUSTOM_COMMAND(
        OUTPUT "${extension_path}/${extension_control_script}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} -E cat ${EXTENSION_SCHEMA_SOURCES} > "${extension_path}/${extension_control_script}"
        DEPENDS ${EXTENSION_DEPLOY_SOURCES} ${EXTENSION_SCHEMA_SOURCES}
        COMMENT "Generating ${EXTENSION_NAME} extension script to ${extension_path}/${extension_control_script}"
)

ADD_CUSTOM_COMMAND(
        OUTPUT  "${extension_path}/${extension_control_file}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/${extension_control_file}" "${extension_path}/${extension_control_file}"
        DEPENDS ${extension_control_file}
        COMMENT "Copying ${extension_control_file} to ${extension_path}"
)

ADD_CUSTOM_TARGET( extension.${EXTENSION_NAME} ALL DEPENDS "${extension_path}/${extension_control_file}" "${extension_path}/${extension_control_script}" "${extension_path}/${update_control_script}" )

INSTALL ( FILES "${extension_path}/hive_fork_manager_update_script_generator.sh"
          DESTINATION ${POSTGRES_SHAREDIR}/extension
          PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
          GROUP_EXECUTE GROUP_READ
          WORLD_EXECUTE WORLD_READ
        )
INSTALL ( FILES "${CMAKE_CURRENT_SOURCE_DIR}/update.sql"
        DESTINATION ${POSTGRES_SHAREDIR}/extension
        PERMISSIONS OWNER_WRITE OWNER_READ
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

