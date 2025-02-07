#! /bin/sh

# initdb will have just created a default postgresql.conf file in $PGDATA.
# Edit it to include anything we need.  Right now we're just adding two
# include directories for our customizations.
#
# There will be two types of customizations: ones needed by all haf
# users (like loading mandatory things like the query supervisor),
# and options that are intended to be customized by the node operator
# (tuning parameters, logging options, etc).
#
# The default customizations will be in /etc/postgresql/conf.d, and
# files containing those customizations will be baked into the docker image.
#
# The node operator customizations will be in /etc/postgresql/haf_api_node_conf.d
# and be empty by default
sed -i -e '/^#include_if_exists/i                                                            # can add configuration options' \
       -e '/^#include_if_exists/i include_dir = '\''/etc/postgresql/haf_api_node_conf.d'\''  # additional directory where haf_api_node users' \
       -e '/^#include_if_exists/i                                                            # the docker image' \
       -e '/^#include_if_exists/i include_dir = '\''/etc/postgresql/conf.d'\''               # default customization options built into' \
       "$PGDATA/postgresql.conf"

# We had to include these lines to allow us to install pg_cron correclty using the initdb scripts
# we can now remove them, we'll be putting those lines in a conf.d file in the include
# directories configured above
sed -i -e '/^shared_preload_libraries='\''pg_cron'\''/d' \
       -e '/^cron.database_name='\''haf_block_log'\''/d' \
       "$PGDATA/postgresql.conf"
