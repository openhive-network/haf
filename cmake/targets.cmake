MACRO( ADD_SUBDIRECTORY_WITH_INCLUDES subdirectory )
    INCLUDE_DIRECTORIES( ${subdirectory}/include )
    ADD_SUBDIRECTORY( ${subdirectory} )
ENDMACRO()

MACRO( ADD_RUNTIME_LOADED_LIB target_name )
    FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )
    ADD_LIBRARY( ${target_name} SHARED ${sources} )

    SETUP_COMPILER( ${target_name} )
    SETUP_CLANG_TIDY( ${target_name} )

    ADD_POSTGRES_INCLUDES( ${target_name} )
    ADD_POSTGRES_LIBRARIES( ${target_name} )
ENDMACRO()

MACRO( ADD_RUNTIME_LOADED_EXE target_name )
    FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )
    ADD_EXECUTABLE( ${target_name} ${sources} )

    SETUP_COMPILER( ${target_name} )
    SETUP_CLANG_TIDY( ${target_name} )

    ADD_POSTGRES_INCLUDES( ${target_name} )
    ADD_POSTGRES_LIBRARIES( ${target_name} )
ENDMACRO()

MACRO( ADD_LOADTIME_LOADED_LIB target_name )
    SET( test_lib test_${target_name} )
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
ENDMACRO()

MACRO( ADD_STATIC_LIB target_name )
    SET( test_lib test_${target_name} )
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
ENDMACRO()
