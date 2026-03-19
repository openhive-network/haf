#! /bin/bash
set -euo pipefail

NC_PID=0
cleanup() {
    echo "Received shutdown signal, exiting..."
    [[ $NC_PID -ne 0 ]] && kill $NC_PID 2>/dev/null || true
    exit 0
}
trap cleanup TERM INT QUIT

echo "You can now connect to the database.  This container will continue to exist until you shut it down"

# gitlab healthchecks are testing whether this port is open so we know when container started
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n" | nc -l -p $HTTP_PORT &
    NC_PID=$!
    wait $NC_PID || true
    NC_PID=0
done
