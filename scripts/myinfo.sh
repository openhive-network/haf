#! /bin/bash
find / -name postgresql*.log 2>/dev/null
echo $SHELL
echo $0
POSTGRESLOG=$(find / -name postgresql*.log)
echo $POSTGRESLOG
ls -lah $POSTGRESLOG
echo "mtlk Listing 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing postgres log"
