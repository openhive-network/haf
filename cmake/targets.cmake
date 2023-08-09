MACRO( LIBRARIES_PARAMETERS )
    SET(options NO_OPTIONS)
    SET(oneValueArgs TARGET_NAME )
    SET(multiValueArgs LINK_WITH )
    CMAKE_PARSE_ARGUMENTS( LIBRARY "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    SET( target_name ${LIBRARY_TARGET_NAME} )
    SET( test_lib test_${LIBRARY_TARGET_NAME}  )
ENDMACRO()

MACRO( ADD_SUBDIRECTORY_WITH_INCLUDES subdirectory )
    INCLUDE_DIRECTORIES( ${subdirectory}/include )
    ADD_SUBDIRECTORY( ${subdirectory} )
ENDMACRO()

MACRO( ADD_RUNTIME_LOADED_LIB )
    LIBRARIES_PARAMETERS( ${ARGV} )
    FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )

    ADD_LIBRARY( ${target_name} SHARED ${sources} )

    SETUP_COMPILER( ${target_name} )
    SETUP_CLANG_TIDY( ${target_name} )

    ADD_POSTGRES_INCLUDES( ${target_name} )
    ADD_POSTGRES_LIBRARIES( ${target_name} )

    TARGET_LINK_LIBRARIES( ${target_name} PUBLIC ${LIBRARY_LINK_WITH} )
ENDMACRO()

MACRO( ADD_LOADTIME_LOADED_LIB )
    LIBRARIES_PARAMETERS( ${ARGV} )

    FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )
    ADD_LIBRARY( ${target_name} MODULE ${sources} )
    # test lib used by unit tests
    ADD_LIBRARY( ${test_lib} STATIC ${sources} )

    SETUP_COMPILER( ${target_name} )
    SETUP_COMPILER( ${test_lib} )
    SETUP_CLANG_TIDY( ${target_name} )
    TARGET_COMPILE_DEFINITIONS( ${test_lib} PRIVATE UNITTESTS )

    ADD_POSTGRES_INCLUDES( ${target_name} )
    ADD_POSTGRES_INCLUDES( ${test_lib} )
    ADD_POSTGRES_LIBRARIES( ${target_name} )

    TARGET_LINK_LIBRARIES( ${target_name} PUBLIC ${LIBRARY_LINK_WITH} )
    TARGET_LINK_LIBRARIES( ${test_lib} PUBLIC ${LIBRARY_LINK_WITH} )
ENDMACRO()

MACRO( ADD_STATIC_LIB )
    LIBRARIES_PARAMETERS( ${ARGV} )

    FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )
    ADD_LIBRARY( ${target_name} STATIC ${sources} )
    # test lib used by unit tests
    ADD_LIBRARY( ${test_lib} STATIC ${sources} )

    SETUP_COMPILER( ${target_name} )
    SETUP_COMPILER( ${test_lib} )
    SETUP_CLANG_TIDY( ${target_name} )
    TARGET_COMPILE_DEFINITIONS( ${test_lib} PRIVATE UNITTESTS )

    ADD_POSTGRES_INCLUDES( ${target_name} )
    ADD_POSTGRES_INCLUDES( ${test_lib} )
    ADD_POSTGRES_LIBRARIES( ${target_name} )

    TARGET_LINK_LIBRARIES( ${target_name} PUBLIC ${LIBRARY_LINK_WITH} )
    TARGET_LINK_LIBRARIES( ${test_lib} PUBLIC ${LIBRARY_LINK_WITH} )
ENDMACRO()
