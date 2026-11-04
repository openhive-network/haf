#! /bin/bash
# Checks that a script sourcing common.sh can chmod "$LOG_FILE" immediately,
# even when the tee that common.sh starts asynchronously is slow to create it
# (setup_pghero.sh and setup_postgres.sh do exactly that).

set -euo pipefail

SCRIPTS_DIR="$( cd -- "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

REAL_TEE=$(command -v tee)
mkdir "$WORKDIR/bin"
cat > "$WORKDIR/bin/tee" <<WRAPPER
#! /bin/bash
sleep 2
exec "$REAL_TEE" "\$@"
WRAPPER
chmod +x "$WORKDIR/bin/tee"

cat > "$WORKDIR/caller.sh" <<CALLER
#! /bin/bash
LOG_FILE=caller.log
source "$SCRIPTS_DIR/common.sh"
echo "caller output"
chmod a+w "\$LOG_FILE"
CALLER

cd "$WORKDIR"
umask 022
if ! PATH="$WORKDIR/bin:$PATH" bash caller.sh > caller.out 2>&1; then
  echo "FAIL: caller exited non-zero with a delayed tee:"
  cat caller.out
  exit 1
fi

if [[ "$(stat -c %A caller.log)" != "-rw-rw-rw-" ]]; then
  echo "FAIL: caller.log is not world-writable: $(stat -c %A caller.log)"
  exit 1
fi

# The delayed tee still writes the output once it starts.
for _ in $(seq 50); do
  grep -q "caller output" caller.log && break
  sleep 0.1
done
if ! grep -q "caller output" caller.log; then
  echo "FAIL: caller.log lacks the script's output"
  exit 1
fi

echo "PASS"
