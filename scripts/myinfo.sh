#! /bin/bash
find / -name postgresql*.log 2>/dev/null
echo $SHELL
echo $0
POSTGRESLOG=$(find / -name postgresql*.log)
echo $POSTGRESLOG
ls -lah $POSTGRESLOG
sudo tail -n 1000 $POSTGRESLOG