MACRO( ADD_RUNTIME_LOADED_LIB target_name )
    FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )
    ADD_LIBRARY( ${target_name} SHARED ${sources} )

    SETUP_COMPILER( ${target_name} )
    SETUP_CLANG_TIDY( ${target_name} )

    ADD_BOOST_LIBRARIES( ${target_name} FALSE )

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

    ADD_BOOST_LIBRARIES( ${target_name} FALSE )
    ADD_BOOST_LIBRARIES( ${test_lib} TRUE )

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

    ADD_BOOST_LIBRARIES( ${target_name} TRUE )
    ADD_BOOST_LIBRARIES( ${test_lib} TRUE )

    ADD_POSTGRES_INCLUDES( ${target_name} )
    ADD_POSTGRES_INCLUDES( ${test_lib} )
    ADD_POSTGRES_LIBRARIES( ${target_name} )
ENDMACRO()
