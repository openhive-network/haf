SET( target_name "transaction_controllers")

ADD_STATIC_LIB( ${target_name} )

TARGET_INCLUDE_DIRECTORIES( ${target_name} PRIVATE  ${HAF_DIRECTORY}/hive/libraries/fc/include )