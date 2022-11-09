#!/usr/bin/env bash

export FROM_DB=haf_block_log
export TARGET_DB=ainna

#dump
psql -U dev -d postgres -c "DROP DATABASE $TARGET_DB"
psql -U dev -d postgres -c "CREATE DATABASE $TARGET_DB;"
pg_dump  -Fc  -U dev -d $FROM_DB  -v -f dump.Fcsql
pg_restore --disable-triggers --section=data  -Fc -U dev -f dump.sql -v  dump.Fcsql


# restore pre-data
pg_restore  --section=pre-data  -Fc -U dev -d $TARGET_DB -v  dump.Fcsql

# delete status table contntents
psql -U dev -d $TARGET_DB -c 'DELETE from hive.irreversible_data;'

#restore data
pg_restore --disable-triggers --section=data  -Fc -U dev -d $TARGET_DB -v  dump.Fcsql

#restore post-data
pg_restore --disable-triggers --section=post-data  -Fc -U dev -d $TARGET_DB -v  dump.Fcsql

#is ok ?
psql -U dev -d $TARGET_DB -c 'SELECT COUNT(*) FROM hive.blocks'


