#! /bin/bash
set -euo pipefail

echo "You can now connect to the database.  This this container will continue to exist until you shut it down"

# gitlab healthchecks are testing whether this port is open so we know when container started
while true; do echo -e "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n" | nc -l -p $HTTP_PORT; done
