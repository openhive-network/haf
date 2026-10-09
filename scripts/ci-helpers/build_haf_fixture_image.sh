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
  Pushes <repository>:<commit, 8 chars> and <repository>:<full commit>; does
  nothing but report the existing image when the full-commit tag is already
  in the registry. Requires a buildx builder and a registry login.
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

if [[ ! -f "${HAF_DB_STORE}/pgdata/PG_VERSION" ]]; then
  echo "ERROR: ${HAF_DB_STORE}/pgdata/PG_VERSION not found or not readable - no replayed database to package"
  exit 1
fi
if [[ -f "${HAF_DB_STORE}/pgdata/postmaster.pid" ]]; then
  echo "ERROR: ${HAF_DB_STORE}/pgdata/postmaster.pid exists - the replay cache was not shut down cleanly"
  exit 1
fi

EMPTY_CONTEXT=$(mktemp -d)
trap 'rm -rf "$EMPTY_CONTEXT"' EXIT

echo "Building ${SHORT_TAG} from ${HAF_IMAGE} with database ${HAF_DB_STORE}"
du -sh "$HAF_DB_STORE" || true

# zstd: the database layer is tens of GB, gzip compresses it single-threaded.
# No provenance attestation, so the tag resolves to a plain image manifest.
docker buildx build \
  --file "${SRCROOTDIR}/Dockerfile.fixture" \
  --build-arg BASE_IMAGE="$HAF_IMAGE" \
  --build-context haf_db_store="$HAF_DB_STORE" \
  --label io.hive.image.revision="$HAF_COMMIT" \
  --label io.hive.image.fixture.base="$HAF_IMAGE" \
  --provenance=false \
  --tag "$SHORT_TAG" \
  --tag "$FULL_TAG" \
  --output type=image,push=true,compression=zstd,oci-mediatypes=true \
  "$EMPTY_CONTEXT"

report_fixture "$FULL_TAG"
