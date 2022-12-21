MACRO( SETUP_OUTPUT_DIRECTORIES )
    SET(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    SET(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    SET(GENERATED_FILES_DIRECTORY_ROOT ${CMAKE_BINARY_DIR}/generated/)
    SET(GENERATED_FILES_DIRECTORY ${CMAKE_BINARY_DIR}/generated/gen)
    FILE( MAKE_DIRECTORY ${GENERATED_FILES_DIRECTORY} )
ENDMACRO()

MACRO( SETUP_COMPILER target_name )
    TARGET_COMPILE_OPTIONS( ${target_name}  PRIVATE -Wall )
    TARGET_INCLUDE_DIRECTORIES( ${target_name}
            PRIVATE
            ${PROJECT_SOURCE_DIR}/common_includes
            "."
            ${GENERATED_FILES_DIRECTORY_ROOT}
    )
ENDMACRO()

MACRO( ENABLE_NINJA_COLORFUL_OUTPUT )
    if( "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" )
        add_compile_options(-fcolor-diagnostics)
    elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
        add_compile_options(-fdiagnostics-color=always)
    else()
        message( AUTHOR_WARNING "You are using the Ninja generator with the unsupported compiler. Colorful output may not be available." )
    endif()
ENDMACRO()
