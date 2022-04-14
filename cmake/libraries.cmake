MACRO( ADD_BOOST_LIBRARIES target_name static_library )
    SET( BOOST_COMPONENTS )
    LIST( APPEND BOOST_COMPONENTS
            thread
            date_time
            system
            filesystem
            program_options
            serialization
            unit_test_framework
            context locale iostreams
    )
    IF( ${static_library} )
      SET( Boost_USE_STATIC_LIBS ON CACHE STRING "ON or OFF" FORCE )
    else()
      SET( Boost_USE_STATIC_LIBS OFF CACHE STRING "ON or OFF" FORCE )
    endif()

    FIND_PACKAGE( Boost 1.53 REQUIRED COMPONENTS ${BOOST_COMPONENTS} )

    TARGET_LINK_LIBRARIES( ${target_name} PRIVATE ${Boost_LIBRARIES} )
ENDMACRO()

MACRO( ADD_POSTGRES_LIBRARIES target_name )
    FIND_LIBRARY(PQ_LIB pq)
    IF ( PQ_LIB )
        TARGET_LINK_LIBRARIES( ${target_name} PRIVATE ${PQ_LIB} )
    ELSE()
        MESSAGE( WARNING "PQ_LIB not found" )
    ENDIF()
ENDMACRO()

MACRO( ADD_POSTGRES_INCLUDES target_name )
    TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE ${SERVER_INCLUDE_LIST_DIR} )
ENDMACRO()
