#!/usr/bin/env bash
# Entrypoint of the shared HAF service (.aidev/shared-haf.compose.yml), run in
# the hive/haf/fixture-5m image of HAF_FIXTURE_COMMIT.
#
# 1. Refuses a data root that is not ZFS: the per-run clones are only
#    copy-on-write there (file_copy_method = clone needs block cloning).
# 2. Seeds the version once: copies the image's replayed cluster to
#    <root>/<commit>/haf_db_store (through <commit>.partial, so an interrupted
#    copy is never served) and from then on reuses it.
# 3. Points /home/hived/datadir/haf_db_store at that copy — the path the image's
#    postgresql.conf and tablespace were written for — adds the clone setting
#    and hands over to the HAF entrypoint, which starts PostgreSQL and then runs
#    serve.sh.
#
# Environment: HAF_FIXTURE_COMMIT (40-hex commit of the image), HAF_SHARED_ROOT
# (the ZFS dataset mounted into the container).
set -euo pipefail

commit="${HAF_FIXTURE_COMMIT:?HAF_FIXTURE_COMMIT must name the fixture image commit}"
root="${HAF_SHARED_ROOT:?HAF_SHARED_ROOT must name the mounted ZFS dataset}"
here="$(cd "$(dirname "$0")" && pwd -P)"
image_store=/home/hived/datadir/haf_db_store

if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    echo "HAF_FIXTURE_COMMIT must be a full 40-character commit SHA, got '$commit'" >&2
    exit 1
fi
fs="$(stat -f -c %T "$root")"
if [ "$fs" != zfs ]; then
    echo "$root is $fs, not ZFS: clones would be full copies; mount a ZFS dataset with block cloning there" >&2
    exit 1
fi

store="$root/$commit/haf_db_store"
if ! sudo -n test -f "$store/pgdata/PG_VERSION"; then
    if sudo -n test -e "$root/$commit"; then
        echo "$root/$commit exists but holds no cluster; remove it to seed again" >&2
        exit 1
    fi
    if [ -L "$image_store" ] || ! sudo -n test -f "$image_store/pgdata/PG_VERSION"; then
        echo "this image has no replayed cluster at $image_store to seed from" >&2
        exit 1
    fi
    echo "seeding $root/$commit from the image's cluster"
    sudo -n rm -rf "$root/$commit.partial"
    sudo -n mkdir -p "$root/$commit.partial"
    sudo -n cp -a "$image_store" "$root/$commit.partial/"
    sudo -n mv "$root/$commit.partial" "$root/$commit"
fi

if [ ! -L "$image_store" ]; then
    sudo -n rm -rf "$image_store"
    sudo -n ln -s "$store" "$image_store"
fi

conf_d=/home/hived/datadir/haf_postgresql_conf.d
sudo -n mkdir -p "$conf_d"
sudo -n install -o postgres -g postgres -m 644 "$here/postgresql.conf" "$conf_d/50-haf-shared.conf"

exec /home/hived/docker_entrypoint.sh --execute-maintenance-script="$here/serve.sh"
