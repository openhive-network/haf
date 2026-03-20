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

# Keep pg_cron lines from postgresql.conf.sample in place — they're needed during
# the temp server phase when init scripts run (CREATE EXTENSION pg_cron requires
# the shared library and its GUCs to be available). The conf.d files will also
# set these values, but duplicates are harmless (last value wins).
