#! /bin/bash

set -x

echo find / -name postgres*.conf 2>/dev/null
find / -name postgres*.conf 2>/dev/null

echo ENV
env | sort

echo find / -name postgresql*.log 2>/dev/null
find / -name postgresql*.log 2>/dev/null



echo ln -s /var/log/postgresql var_log_postgresql_link
ln -s /var/log/postgresql var_log_postgresql_link

echo find / -name var_log_postgresql_link 2>/dev/null
find / -name var_log_postgresql_link 2>/dev/null

POSTGRESLOG=$(find / -name postgresql*.log)
echo $POSTGRESLOG
ls -lah $POSTGRESLOG

echo sudo tail -n 1000 $POSTGRESLOG
sudo tail -n 1000 $POSTGRESLOG

echo find / -name postgresql_logs 2>/dev/null
find / -name postgresql_logs || true 2>/dev/null