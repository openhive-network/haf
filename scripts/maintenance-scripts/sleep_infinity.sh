#! /bin/bash
set -xeuo pipefail

# gitlab healthchecks are testing whether this port is open so we know when container started
python3 -m http.server $HTTP_PORT
