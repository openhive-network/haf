#!/usr/bin/env bash
# One-shot `seed` service of the shared HAF (.aidev/shared-haf.compose.yml), run
# in the hive/haf image of HAF_VERSION before `haf` starts.
#
# 1. Refuses a data root that is not ZFS: the per-run clones are only
#    copy-on-write there (file_copy_method = clone needs block cloning).
# 2. Seeds the version once: replays the first 5M blocks of
#    <root>/block_log_5m/block_log as CI's prepare_haf_data does
#    (docker/config_5M.ini, --replay-blockchain --stop-at-block=5000000) in
#    <root>/<version>.partial, checks the cluster, keeps only its haf_db_store
#    and moves it to <root>/<version>, so an interrupted replay is never served.
#    Exits 0 without replaying when the version is already there.
#
# The replay runs the image's entrypoint with DATADIR in the partial directory,
# so PostgreSQL records the tablespace there; it is relinked relative to pgdata
# (../../tablespace, as in CI's replay caches) before the move. `haf`
# bind-mounts the result at the image's own haf_db_store path rather than
# symlinking it: setup_postgres.sh refuses a tablespace whose resolved location
# differs from the one it is given.
#
# The block log is never written: the replay gets a copy, which block cloning
# makes free on the dataset.
#
# Environment: HAF_VERSION (40-hex HAF commit of the image), HAF_SHARED_ROOT
# (the ZFS dataset mounted into the container).
set -euo pipefail

version="${HAF_VERSION:?HAF_VERSION must name the HAF commit of the image}"
root="${HAF_SHARED_ROOT:?HAF_SHARED_ROOT must name the mounted ZFS dataset}"
config_ini=/aidev/config_5M.ini
stop_at_block=5000000

if [[ ! "$version" =~ ^[0-9a-f]{40}$ ]]; then
    echo "HAF_VERSION must be a full 40-character commit SHA, got '$version'" >&2
    exit 1
fi
fs="$(stat -f -c %T "$root")"
if [ "$fs" != zfs ]; then
    echo "$root is $fs, not ZFS: clones would be full copies; mount a ZFS dataset with block cloning there" >&2
    exit 1
fi

store="$root/$version/haf_db_store"
if sudo -n test -f "$store/pgdata/PG_VERSION"; then
    echo "$root/$version is already seeded"
    exit 0
fi

# The daemon creates a missing bind source as an empty directory; such a
# leftover holds nothing to keep.
sudo -n rmdir "$store" "$root/$version" 2>/dev/null || true
if sudo -n test -e "$root/$version"; then
    echo "$root/$version exists but holds no cluster; remove it to seed again" >&2
    exit 1
fi
block_log="$root/block_log_5m/block_log"
if [ ! -f "$block_log" ]; then
    echo "no block log at $block_log to replay $version from: download it to block_log_5m/block_log in the data root" \
        "(curl -o <data root>/block_log_5m/block_log https://gtg.openhive.network/get/blockchain/block_log.5M)" >&2
    exit 1
fi

part="$root/$version.partial"
part_store="$part/haf_db_store"
pgdata="$part_store/pgdata"
echo "seeding $root/$version by replaying $stop_at_block blocks of $block_log"
sudo -n rm -rf "$part"
sudo -n install -d -o hived -g users "$part" "$part/blockchain"
sudo -n install -o hived -g users -m 644 "$config_ini" "$part/config.ini"
for file in "$block_log" "$block_log.artifacts"; do
    [ -f "$file" ] || continue
    sudo -n cp --reflink=auto "$file" "$part/blockchain/"
    sudo -n chown hived:users "$part/blockchain/$(basename "$file")"
done

DATADIR="$part" SHUTDOWN_VACUUM_ANALYZE=true /home/hived/docker_entrypoint.sh \
    --replay-blockchain --stop-at-block="$stop_at_block" --exit-before-sync

require_clean_shutdown() {
    if sudo -n test -e "$pgdata/postmaster.pid"; then
        echo "PostgreSQL did not shut down cleanly ($pgdata/postmaster.pid exists); refusing to serve $part" >&2
        exit 1
    fi
}

if ! sudo -n test -f "$pgdata/PG_VERSION"; then
    echo "the replay left no cluster at $pgdata" >&2
    exit 1
fi
require_clean_shutdown

mapfile -t links < <(sudo -nu postgres find "$pgdata/pg_tblspc" -mindepth 1 -maxdepth 1)
if [ "${#links[@]}" != 1 ] || [ "$(sudo -nu postgres readlink "${links[0]}")" != "$part_store/tablespace" ]; then
    echo "expected the replay's one tablespace at $part_store/tablespace, found: ${links[*]:-none}" >&2
    exit 1
fi
sudo -nu postgres ln -sfn ../../tablespace "${links[0]}"
if [ "$(sudo -nu postgres realpath -e "${links[0]}")" != "$(sudo -n realpath -e "$part_store/tablespace")" ]; then
    echo "relinking the tablespace ${links[0]} to ../../tablespace failed" >&2
    exit 1
fi

# Started as the entrypoint left it configured, reading the cluster through
# the relinked tablespace.
sudo -n /etc/init.d/postgresql start
head_block="$(sudo -nu postgres psql -X -d haf_block_log -Atc 'select max(num) from hafd.blocks')"
sudo -n /etc/init.d/postgresql stop
require_clean_shutdown
if [ "$head_block" != "$stop_at_block" ]; then
    echo "haf_block_log of the replay is at head block '$head_block', not $stop_at_block; refusing to serve $part" >&2
    exit 1
fi

sudo -n find "$part" -mindepth 1 -maxdepth 1 ! -name haf_db_store -exec rm -rf {} +
sudo -n mv "$part" "$root/$version"
echo "seeded $root/$version at head block $head_block"
