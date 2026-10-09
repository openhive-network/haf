#! /bin/bash
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SRCROOTDIR="$SCRIPTPATH/../.."

HAF_IMAGE=""
DATA_CACHE=""
FIXTURE_REPOSITORY=""
HAF_COMMIT=""

print_help () {
cat <<-EOF
  Usage: $0 [OPTION[=VALUE]]...

  Builds and pushes a HAF fixture image: the given HAF image with the PostgreSQL
  cluster of a replay cache baked into a layer (see Dockerfile.fixture).
  Pushes <repository>:<commit, 8 chars>, starts it once and, only when
  PostgreSQL comes up on the baked cluster, tags it <repository>:<full commit>;
  does nothing but report the existing image when the full-commit tag is
  already in the registry. Makes the local replay cache world-readable (the
  image restores postgres ownership and the entrypoint the pgdata mode).
  Requires passwordless sudo, a buildx builder and a registry login.
  OPTIONS:
      --haf-image=IMAGE           HAF image that produced the replay cache (fixture base)
      --data-cache=PATH           Replay cache directory (containing datadir/haf_db_store)
      --fixture-repository=REPO   Registry repository to push to (e.g. registry.gitlab.syncad.com/hive/haf/fixture-5m)
      --haf-commit=SHA            HAF commit the replay cache belongs to
      --help|-h|-?                Display this help screen and exit
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --haf-image=*)
        HAF_IMAGE="${1#*=}"
        ;;
    --data-cache=*)
        DATA_CACHE="${1#*=}"
        ;;
    --fixture-repository=*)
        FIXTURE_REPOSITORY="${1#*=}"
        ;;
    --haf-commit=*)
        HAF_COMMIT="${1#*=}"
        ;;
    --help|-h|-\?)
        print_help
        exit 0
        ;;
    *)
        echo "ERROR: '$1' is not a valid option"
        print_help
        exit 1
        ;;
  esac
  shift
done

: "${HAF_IMAGE:?Missing --haf-image}"
: "${DATA_CACHE:?Missing --data-cache}"
: "${FIXTURE_REPOSITORY:?Missing --fixture-repository}"
: "${HAF_COMMIT:?Missing --haf-commit}"

if [[ ! "$HAF_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  echo "ERROR: --haf-commit must be a full 40-character commit SHA, got '$HAF_COMMIT'"
  exit 1
fi

SHORT_TAG="${FIXTURE_REPOSITORY}:${HAF_COMMIT:0:8}"
FULL_TAG="${FIXTURE_REPOSITORY}:${HAF_COMMIT}"
HAF_DB_STORE="${DATA_CACHE}/datadir/haf_db_store"

report_fixture () {
  local tag="$1"
  local digest
  digest=$(docker buildx imagetools inspect "$tag" | awk '/^Digest:/ && !d {d = $2} END {print d}')
  echo "Fixture image: ${tag}@${digest}"

  # Layer sizes in a manifest are compressed blob sizes; the last layer is the database
  local sizes
  sizes=$(docker buildx imagetools inspect --raw "$tag" | tr -d ' \n' | sed 's/.*"layers":\[//' | grep -o '"size":[0-9]*' | cut -d: -f2 || true)
  if [[ -z "$sizes" ]]; then
    echo "Compressed size: unavailable (${tag} is not a single-platform manifest)"
    return
  fi
  echo "$sizes" | awk '{ total += $1; last = $1 } END {
    printf "Compressed size: %.2f GiB total, %.2f GiB database layer (%d layers)\n", total / 1073741824, last / 1073741824, NR }'
}

if docker buildx imagetools inspect "$FULL_TAG" >/dev/null 2>&1; then
  echo "Fixture ${FULL_TAG} already exists, skipping build"
  report_fixture "$FULL_TAG"
  exit 0
fi

# The replayed cluster is postgres-owned with pgdata 0700, so probe it as root
# to tell a missing database from one the job user cannot read
if ! sudo -n test -f "${HAF_DB_STORE}/pgdata/PG_VERSION"; then
  echo "ERROR: ${HAF_DB_STORE}/pgdata/PG_VERSION not found - no replayed database to package"
  exit 1
fi
if sudo -n test -f "${HAF_DB_STORE}/pgdata/postmaster.pid"; then
  echo "ERROR: ${HAF_DB_STORE}/pgdata/postmaster.pid exists - the replay cache was not shut down cleanly"
  exit 1
fi

# The build context is read as the job user. Only this local extraction is
# relaxed: COPY --chown sets postgres ownership in the image and
# docker_entrypoint.sh restores pgdata to 0700 before starting PostgreSQL.
sudo -n chmod -R a+rX "$HAF_DB_STORE"

EMPTY_CONTEXT=$(mktemp -d)
CHECK_CONTAINER="haf-fixture-check-${HAF_COMMIT:0:8}-$$"
cleanup () {
  rm -rf "$EMPTY_CONTEXT"
  docker rm -f "$CHECK_CONTAINER" >/dev/null 2>&1 || true
  docker image rm "$SHORT_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Building ${SHORT_TAG} from ${HAF_IMAGE} with database ${HAF_DB_STORE}"
du -sh "$HAF_DB_STORE" || true

# zstd: the database layer is tens of GB, gzip compresses it single-threaded.
# No provenance attestation, so the tag resolves to a plain image manifest.
# Only the short tag is pushed here: the full-commit tag marks a fixture that
# has been started successfully, and its presence makes later runs skip the build.
docker buildx build \
  --file "${SRCROOTDIR}/Dockerfile.fixture" \
  --build-arg BASE_IMAGE="$HAF_IMAGE" \
  --build-context haf_db_store="$HAF_DB_STORE" \
  --label io.hive.image.revision="$HAF_COMMIT" \
  --label io.hive.image.fixture.base="$HAF_IMAGE" \
  --provenance=false \
  --tag "$SHORT_TAG" \
  --output type=image,push=true,compression=zstd,oci-mediatypes=true \
  "$EMPTY_CONTEXT"

echo "Starting ${SHORT_TAG} to check that PostgreSQL comes up on the baked cluster"
docker run --detach --name "$CHECK_CONTAINER" "$SHORT_TAG" >/dev/null

START_TIMEOUT=600
head_block=""
for (( waited = 0; waited < START_TIMEOUT; waited += 5 )); do
  if [[ "$(docker inspect --format '{{.State.Running}}' "$CHECK_CONTAINER")" != "true" ]]; then
    break
  fi
  if head_block=$(docker exec "$CHECK_CONTAINER" psql -h localhost -U haf_admin -d haf_block_log -Atc 'select max(num) from hafd.blocks' 2>/dev/null); then
    break
  fi
  head_block=""
  sleep 5
done

if [[ -z "$head_block" ]]; then
  echo "ERROR: PostgreSQL did not come up on the baked cluster of ${SHORT_TAG} within ${START_TIMEOUT}s; ${FULL_TAG} not tagged"
  docker logs --tail 100 "$CHECK_CONTAINER" 2>&1 || true
  exit 1
fi
echo "Fixture started: haf_block_log head block ${head_block}"

docker buildx imagetools create --tag "$FULL_TAG" "$SHORT_TAG"

report_fixture "$FULL_TAG"
