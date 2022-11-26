MACRO( ADD_PSQL_EXTENSION )
    set(multiValueArgs DEPLOY_SOURCES UPDATE_SOURCES)
    set(OPTIONS "")
    set(oneValueArgs NAME )

    CMAKE_PARSE_ARGUMENTS( EXTENSION "${OPTIONS}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    MESSAGE( STATUS "EXTENSION_NAME: ${EXTENSION_NAME}" )

    SET( extension_path  "${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME}" )

    FILE( MAKE_DIRECTORY "${extension_path}" "${extension_path}/update" )

    SET( UPDATE_NAME "${EXTENSION_NAME}_update--${HAF_GIT_REVISION_SHA}" )
    SET( update_control_script ${UPDATE_NAME}.sql )

    SET( PROXY_UPDATE_VER "UPDATE--${HAF_GIT_REVISION_SHA}" )

    SET( update_path "${extension_path}/update/")

    SET( extension_control_file ${EXTENSION_NAME}.control )

    SET( extension_control_script ${EXTENSION_NAME}--${HAF_GIT_REVISION_SHA}.sql )

    SET( PROXY_GIT_VER "PROXY--${HAF_GIT_REVISION_SHA}" )
    SET( PROXY_UPDATE_VER "UPDATE--${HAF_GIT_REVISION_SHA}" )

    MESSAGE( STATUS "VERSION: ${HAF_GIT_REVISION_SHA}" )

    #MESSAGE( STATUS "EXTENSION_DEPLOY_SOURCES: ${EXTENSION_DEPLOY_SOURCES}")
    #MESSAGE( STATUS "EXTENSION_UPDATE_SOURCES: ${EXTENSION_UPDATE_SOURCES}")

    MESSAGE( STATUS "CONFIGURING the update script generator script: ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME}/hive_fork_manager_update_script_generator.sh" )

    CONFIGURE_FILE( "${CMAKE_CURRENT_SOURCE_DIR}/hive_fork_manager_update_script_generator.sh"
      "${extension_path}/hive_fork_manager_update_script_generator.sh" @ONLY)

    ADD_CUSTOM_COMMAND(
            OUTPUT  "${extension_path}/${extension_control_file}" "${extension_path}/${extension_control_script}"
            COMMAND sed 's/@HAF_GIT_REVISION_SHA@/${HAF_GIT_REVISION_SHA}/g' ${extension_control_file}  > ${extension_path}/${extension_control_file}
            COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/merge_sql.sh ${EXTENSION_DEPLOY_SOURCES} > ${extension_path}/${EXTENSION_NAME}--${PROXY_GIT_VER}.sql
            COMMAND sed 's/@HAF_GIT_REVISION_SHA@/${HAF_GIT_REVISION_SHA}/g' ${extension_path}/${EXTENSION_NAME}--${PROXY_GIT_VER}.sql  > ${extension_path}/${EXTENSION_NAME}--${HAF_GIT_REVISION_SHA}.sql
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            DEPENDS ${EXTENSION_DEPLOY_SOURCES} ${extension_control_file}
            COMMENT "Generating ${EXTENSION_NAME} files to ${extension_path}"
    )

    ADD_CUSTOM_COMMAND(
            OUTPUT "${extension_path}/${update_control_script}"
            COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/merge_sql.sh ${EXTENSION_UPDATE_SOURCES} > ${update_path}/${UPDATE_NAME}--${PROXY_UPDATE_VER}.sql
            COMMAND sed 's/@HAF_GIT_REVISION_SHA@/${HAF_GIT_REVISION_SHA}/g' ${update_path}/${UPDATE_NAME}--${PROXY_UPDATE_VER}.sql  > ${extension_path}/${update_control_script}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            DEPENDS ${EXTENSION_UPDATE_SOURCES}
            COMMENT "Generating ${EXTENSION_NAME} helper update scripts to ${update_path}, final upgrade script: ${extension_path}/${update_control_script}"
    )

    ADD_CUSTOM_TARGET( extension.${EXTENSION_NAME} ALL DEPENDS ${extension_path}/${extension_control_file} ${extension_path}/${extension_control_script} ${extension_path}/${update_control_script} )

    INSTALL ( FILES "${extension_path}/hive_fork_manager_update_script_generator.sh"
              DESTINATION ${POSTGRES_SHAREDIR}/extension
              PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
              GROUP_EXECUTE GROUP_READ
              WORLD_EXECUTE WORLD_READ
            )
    INSTALL ( FILES "${extension_path}/${update_control_script}" "${extension_path}/${extension_control_file}" "${extension_path}/${extension_control_script}"
              DESTINATION ${POSTGRES_SHAREDIR}/extension
              PERMISSIONS OWNER_WRITE OWNER_READ
              GROUP_READ
              WORLD_READ
            )

ENDMACRO()

