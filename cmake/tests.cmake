MACRO( ADD_UNIT_TESTS module_name)
    SET( test_target unit.${module_name} )
    FILE( GLOB_RECURSE sources ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp )
    MESSAGE( STATUS "TEST sources : ${sources}" )
    ADD_EXECUTABLE( ${test_target} ${sources} )

    ADD_DEPENDENCIES( ${test_target} googletest )

    SETUP_COMPILER( ${test_target} )
    ADD_POSTGRES_INCLUDES( ${test_target} )
    TARGET_INCLUDE_DIRECTORIES( ${test_target} PRIVATE ${CMAKE_SOURCE_DIR}/tests/unit/mockups )

    ADD_POSTGRES_LIBRARIES( ${test_target} )
    IF ( TARGET test_${module_name} )
        TARGET_LINK_LIBRARIES( ${test_target} PRIVATE test_${module_name} )
    ENDIF()
    TARGET_LINK_LIBRARIES( ${test_target} PRIVATE ${CMAKE_BINARY_DIR}/lib/libgmock.a )
    TARGET_LINK_LIBRARIES( ${test_target} PRIVATE ${CMAKE_BINARY_DIR}/lib/libgtest.a )


    ADD_TEST( NAME test.${test_target} COMMAND ${test_target} )
    MESSAGE( STATUS "Added unit tests '${test_target}'" )
ENDMACRO()