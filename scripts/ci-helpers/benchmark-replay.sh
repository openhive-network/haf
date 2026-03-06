#!/bin/bash
set -euo pipefail

# benchmark-replay.sh — Compare HAF replay performance between two Docker images
#
# Usage:
#   benchmark-replay.sh <image_a> <image_b> [options]
#
# Examples:
#   # Compare two images by registry tag (use HAF_REGISTRY_TAG from CI build trace)
#   benchmark-replay.sh registry.gitlab.syncad.com/hive/haf:9daf4c2d \
#                       registry.gitlab.syncad.com/hive/haf:067b466a
#
#   # With labels and extra hived args
#   benchmark-replay.sh haf:abc123 haf:def456 \
#       --label-a irrev --label-b develop \
#       --args-a "--psql-lite-mode" \
#       --blocks 5000000
#
# Notes:
#   - Run on a CI builder with /blockchain/block_log_5m available
#   - Requires root or docker-group membership
#   - Drops filesystem caches between runs for fairness
#   - Image tags: use HAF_REGISTRY_TAG from the haf_image_build job trace,
#     NOT the git commit SHA (they differ when the builder image is cached)

BLOCK_LOG_DIR="/blockchain/block_log_5m"
STOP_AT_BLOCK=5000000
BASE_DIR="/cache/haf_benchmark_$$"
RESULTS_FILE="/tmp/haf_benchmark_results_$$.txt"
LABEL_A="image_a"
LABEL_B="image_b"
ARGS_A=""
ARGS_B=""

print_help() {
    sed -n '3,/^$/p' "$0" | sed 's/^# \?//'
    echo "Options:"
    echo "  --block-log-dir DIR   Path to block log directory (default: /blockchain/block_log_5m)"
    echo "  --blocks N            Stop replay at block N (default: 5000000)"
    echo "  --label-a NAME        Label for first image (default: image_a)"
    echo "  --label-b NAME        Label for second image (default: image_b)"
    echo "  --args-a ARGS         Extra hived args for first image (e.g., --psql-lite-mode)"
    echo "  --args-b ARGS         Extra hived args for second image"
    echo "  --base-dir DIR        Working directory for data (default: /cache/haf_benchmark_PID)"
    echo "  --help                Show this help"
}

IMAGE_A=""
IMAGE_B=""

while [ $# -gt 0 ]; do
    case "$1" in
        --block-log-dir) BLOCK_LOG_DIR="$2"; shift ;;
        --blocks) STOP_AT_BLOCK="$2"; shift ;;
        --label-a) LABEL_A="$2"; shift ;;
        --label-b) LABEL_B="$2"; shift ;;
        --args-a) ARGS_A="$2"; shift ;;
        --args-b) ARGS_B="$2"; shift ;;
        --base-dir) BASE_DIR="$2"; shift ;;
        --help) print_help; exit 0 ;;
        -*)
            echo "Unknown option: $1" >&2
            print_help >&2
            exit 1
            ;;
        *)
            if [ -z "$IMAGE_A" ]; then
                IMAGE_A="$1"
            elif [ -z "$IMAGE_B" ]; then
                IMAGE_B="$1"
            else
                echo "Too many positional arguments" >&2
                exit 1
            fi
            ;;
    esac
    shift
done

if [ -z "$IMAGE_A" ] || [ -z "$IMAGE_B" ]; then
    echo "Error: two image arguments required" >&2
    print_help >&2
    exit 1
fi

# Verify block log exists
for f in "${BLOCK_LOG_DIR}/block_log"; do
    if [ ! -f "$f" ]; then
        echo "Error: block log not found at $f" >&2
        echo "Specify --block-log-dir or ensure the file exists" >&2
        exit 1
    fi
done

# Minimal config for replay (no p2p, no webserver plugins beyond what entrypoint adds)
write_config() {
    local dest="$1"
    cat > "$dest" <<'EOF'
log-appender = {"appender":"stderr","stream":"std_error","time_format":"iso_8601_microseconds"}
log-logger = {"name":"default","level":"info","appender":"stderr"}
backtrace = yes
plugin = sql_serializer
plugin = state_snapshot
psql-index-threshold = 1000000
shared-file-size = 12G
flush-state-interval = 0
block-log-split = -1
EOF
    chmod 666 "$dest"
}

cleanup_container() {
    docker stop "$1" 2>/dev/null || true
    docker rm -f "$1" 2>/dev/null || true
}

drop_caches() {
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo "(cache drop requires root)"
    sleep 2
}

run_replay() {
    local label="$1" image="$2" extra_args="${3:-}"
    local data_dir="${BASE_DIR}/${label}"
    local container_name="haf_bench_${label}_$$"
    local log_file="/tmp/haf_bench_${label}_$$.log"

    echo ""
    echo "============================================"
    echo " ${label}"
    echo " Image: ${image}"
    echo " Args:  ${extra_args:-<none>}"
    echo "============================================"

    cleanup_container "${container_name}"
    rm -rf "${data_dir}"
    mkdir -p "${data_dir}/blockchain"
    chmod -R 777 "${data_dir}"
    write_config "${data_dir}/config.ini"

    docker pull "${image}" 2>&1 | tail -1 || true

    local start_time
    start_time=$(date +%s)

    # Mount block log files directly into the container's blockchain directory.
    # The HAF entrypoint expects block_log at /home/hived/datadir/blockchain/block_log.
    # Symlinks don't work across mount boundaries, so we bind-mount the files.
    local block_log_mounts="-v ${BLOCK_LOG_DIR}/block_log:/home/hived/datadir/blockchain/block_log:ro"
    if [ -f "${BLOCK_LOG_DIR}/block_log.artifacts" ]; then
        block_log_mounts="${block_log_mounts} -v ${BLOCK_LOG_DIR}/block_log.artifacts:/home/hived/datadir/blockchain/block_log.artifacts:ro"
    fi

    docker run \
        --name "${container_name}" \
        -d \
        -v "${data_dir}:/home/hived/datadir" \
        ${block_log_mounts} \
        -e LOG_FILE=hived.log \
        --shm-size=4g \
        --stop-timeout=180 \
        "${image}" \
        --replay --stop-at-block=${STOP_AT_BLOCK} \
        ${extra_args}

    echo "Started at $(date)"

    local last_blocks="0" stall_count=0
    while docker inspect --format='{{.State.Running}}' "${container_name}" 2>/dev/null | grep -q true; do
        local blocks elapsed rate=""
        blocks=$(docker exec "${container_name}" psql -U haf_admin -d haf_block_log -t -A -c \
            "SELECT COALESCE(consistent_block,0) FROM hafd.hive_state" 2>/dev/null || echo "?")
        elapsed=$(( $(date +%s) - start_time ))
        if [[ "$blocks" =~ ^[0-9]+$ ]] && [ "$blocks" -gt 0 ] && [ "$elapsed" -gt 0 ]; then
            rate=" ($(( blocks * 60 / elapsed )) blk/min)"
        fi
        echo "  [${label}] ${elapsed}s | consistent_block: ${blocks}${rate}"

        if [ "$blocks" = "$last_blocks" ]; then
            stall_count=$((stall_count + 1))
            if [ $stall_count -ge 20 ]; then
                echo "  WARNING: Stalled at block ${blocks} for 10 minutes"
                break
            fi
        else
            stall_count=0
            last_blocks="$blocks"
        fi
        sleep 30
    done

    local end_time duration exit_code
    end_time=$(date +%s)
    duration=$(( end_time - start_time ))
    exit_code=$(docker inspect --format='{{.State.ExitCode}}' "${container_name}" 2>/dev/null || echo "?")

    docker logs "${container_name}" > "${log_file}" 2>&1 || true

    local result="${label}: ${duration}s ($(( duration / 60 ))m$(( duration % 60 ))s) | exit: ${exit_code}"
    echo ""
    echo "  ${result}"
    echo "${result}" >> "${RESULTS_FILE}"

    cleanup_container "${container_name}"
    rm -rf "${data_dir}"
}

# Header
{
    echo "HAF Replay Benchmark"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "CPU: $(lscpu 2>/dev/null | grep 'Model name' | sed 's/.*: *//' || echo 'unknown')"
    echo "RAM: $(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo 'unknown')"
    echo "Block log: ${BLOCK_LOG_DIR}"
    echo "Stop at block: ${STOP_AT_BLOCK}"
    echo ""
    echo "  ${LABEL_A}: ${IMAGE_A} ${ARGS_A:+(${ARGS_A})}"
    echo "  ${LABEL_B}: ${IMAGE_B} ${ARGS_B:+(${ARGS_B})}"
    echo ""
} | tee "${RESULTS_FILE}"

# Cleanup previous runs
cleanup_container "haf_bench_${LABEL_A}_$$"
cleanup_container "haf_bench_${LABEL_B}_$$"
rm -rf "${BASE_DIR}"
trap 'cleanup_container "haf_bench_${LABEL_A}_$$"; cleanup_container "haf_bench_${LABEL_B}_$$"; rm -rf "${BASE_DIR}"' EXIT

drop_caches
run_replay "${LABEL_A}" "${IMAGE_A}" "${ARGS_A}"

drop_caches
run_replay "${LABEL_B}" "${IMAGE_B}" "${ARGS_B}"

echo ""
echo "============================================"
echo " RESULTS"
echo "============================================"
cat "${RESULTS_FILE}"

# Compute speedup if both succeeded
a_time=$(grep "^${LABEL_A}:" "${RESULTS_FILE}" | grep -o '[0-9]*s' | head -1 | tr -d 's')
b_time=$(grep "^${LABEL_B}:" "${RESULTS_FILE}" | grep -o '[0-9]*s' | head -1 | tr -d 's')
if [ -n "$a_time" ] && [ -n "$b_time" ] && [ "$a_time" -gt 0 ] && [ "$b_time" -gt 0 ]; then
    echo ""
    if [ "$a_time" -lt "$b_time" ]; then
        pct=$(( (b_time - a_time) * 100 / b_time ))
        echo "${LABEL_A} is ${pct}% faster than ${LABEL_B} (${a_time}s vs ${b_time}s)"
    elif [ "$b_time" -lt "$a_time" ]; then
        pct=$(( (a_time - b_time) * 100 / a_time ))
        echo "${LABEL_B} is ${pct}% faster than ${LABEL_A} (${b_time}s vs ${a_time}s)"
    else
        echo "Both completed in the same time (${a_time}s)"
    fi
fi

echo ""
echo "Logs: /tmp/haf_bench_${LABEL_A}_$$.log, /tmp/haf_bench_${LABEL_B}_$$.log"
echo "Results: ${RESULTS_FILE}"
