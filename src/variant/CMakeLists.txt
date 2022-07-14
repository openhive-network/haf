ADD_PSQL_EXTENSION(
    NAME variant
    SOURCES sql/variant.sql
)

add_subdirectory( src )

ADD_DEPENDENCIES( extension.${EXTENSION_NAME} variant-${GIT_REVISION} )
