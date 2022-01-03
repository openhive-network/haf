MACRO( ADD_PSQL_EXTENSION )
    CMAKE_PARSE_ARGUMENTS( EXTENSION "" "NAME" SOURCES ${ARGN} )

    FILE( MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/extensions )
    FILE( MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME} )
    SET( extension_path  ${CMAKE_BINARY_DIR}/extensions/${EXTENSION_NAME} )
    SET( extension_control_file ${EXTENSION_NAME}.control )

    SET( extension_control_script ${extension_path}/${EXTENSION_NAME}--${GIT_REVISION}.sql )

    SET( PROXY_GIT_VER "PROXY--${GIT_REVISION}" )

    MESSAGE( STATUS "VERSION: ${GIT_REVISION}" )

    ADD_CUSTOM_COMMAND(
            OUTPUT  ${extension_path}/${extension_control_file} ${extension_path}/${extension_control_script}
            COMMAND rm -rf ${extension_path}/*
            COMMAND sed 's/@GIT_REVISION@/${GIT_REVISION}/g' ${extension_control_file}  > ${extension_path}/${extension_control_file}
            COMMAND ${CMAKE_MODULE_PATH}/merge_sql.sh ${EXTENSION_SOURCES} > ${extension_path}/${EXTENSION_NAME}--${PROXY_GIT_VER}.sql
            COMMAND sed 's/@GIT_REVISION@/${GIT_REVISION}/g' ${extension_path}/${EXTENSION_NAME}--${PROXY_GIT_VER}.sql  > ${extension_path}/${EXTENSION_NAME}--${GIT_REVISION}.sql
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            DEPENDS ${EXTENSION_SOURCES} ${extension_control_file}
            COMMENT "Generate ${EXTENSION_NAME} to ${extension_path}"
    )

    ADD_CUSTOM_TARGET( extension.${EXTENSION_NAME} ALL DEPENDS ${extension_path}/${extension_control_file} ${extension_path}/${extension_control_script} )

    INSTALL( DIRECTORY ${extension_path}/ DESTINATION ${POSTGRES_SHAREDIR}/extension OPTIONAL )

ENDMACRO()
