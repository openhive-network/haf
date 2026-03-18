#!/bin/sh

# After initdb creates a default postgresql.conf, add include_dir directives
# for our configuration and operator-customizable settings.
#
# Also remove the pg_cron lines that were needed during initdb (they're now
# in the conf.d files instead).

sed -i -e '/^#include_if_exists/i                                                            # can add configuration options' \
       -e '/^#include_if_exists/i include_dir = '\''/etc/postgresql/custom.conf.d'\''        # user-overridable configuration' \
       -e '/^#include_if_exists/i                                                            # the docker image' \
       -e '/^#include_if_exists/i include_dir = '\''/etc/postgresql/conf.d'\''               # default customization options built into' \
       "$PGDATA/postgresql.conf"

# Remove pg_cron lines added to postgresql.conf.sample for initdb compatibility
sed -i -e '/^shared_preload_libraries='\''pg_cron'\''/d' \
       -e '/^cron.database_name='\''haf_block_log'\''/d' \
       "$PGDATA/postgresql.conf"
