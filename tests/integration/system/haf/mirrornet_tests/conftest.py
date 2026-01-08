from pathlib import Path
import tempfile
import time
import fcntl
import pytest

import test_tools as tt

from haf_local_tools.system.haf.mirrornet.constants import SKELETON_KEY, WITNESSES_5M
from haf_local_tools.haf_node.monolithic_workaround import (
    apply_block_log_type_to_monolithic_workaround,
)


# Shared timing file for collecting step-by-step timing from parallel workers
TIMING_FILE = Path(tempfile.gettempdir()) / "mirrornet_timing.log"

# Store timing data per test (keyed by test name)
_test_timing = {}


def log_timing(test_name: str, step: str, duration: float):
    """Log timing step for a test. Will be printed when test completes."""
    if test_name not in _test_timing:
        _test_timing[test_name] = []
    _test_timing[test_name].append((step, f"{duration:.2f}s"))

    # Also write to shared file for cross-worker collection
    line = f"{test_name}|{step}|{duration:.2f}s\n"
    with open(TIMING_FILE, "a") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        f.write(line)
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def pytest_configure(config):
    """Clear timing file at start of test session."""
    if TIMING_FILE.exists():
        TIMING_FILE.unlink()


def _print_test_timing(test_name: str, total_time: float):
    """Print timing report for a single test immediately after completion."""
    tt.logger.info(f"{'='*60}")
    tt.logger.info(f"TIMING: {test_name}")
    if test_name in _test_timing:
        for step, duration in _test_timing[test_name]:
            tt.logger.info(f"  {step}: {duration}")
    tt.logger.info(f"  TOTAL: {total_time:.2f}s")
    tt.logger.info(f"{'='*60}")


# Timing instrumentation for mirrornet tests
@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_protocol(item, nextitem):
    """Log timing for each test and print report immediately after."""
    start = time.time()
    yield
    elapsed = time.time() - start
    _print_test_timing(item.name, elapsed)


def _find_node_logs(test_dir: Path) -> list[tuple[str, Path]]:
    """Find all node log files in a test directory."""
    logs = []
    if test_dir.exists():
        # Look for both hived.log (actual hived output) and latest.log (test-tools wrapper)
        for pattern in ["hived.log", "latest.log"]:
            for log_file in test_dir.rglob(pattern):
                node_name = log_file.parent.name
                logs.append((node_name, log_file))
    return logs


def _configure_hived_file_logging(node):
    """Configure hived to write logs to both console and file for debugging.

    Uses iso_8601_realtime_microseconds time format to get real wall-clock timestamps
    that bypass libfaketime interception. This enables accurate timing analysis of
    hived initialization steps during mirrornet tests.
    """
    # File appender that writes to hived.log in the node's data directory
    # Using realtime timestamps to bypass libfaketime for debugging intermittent timeouts
    node.config.log_file_appender = '{"appender":"file","file":"hived.log","time_format":"iso_8601_realtime_microseconds","flush":true}'
    # Logger sends to both console (needed for beekeepy port discovery) and file (for debugging)
    node.config.log_logger = (
        '{"name":"default","level":"info","appenders":["console","file"]}'
        ' {"name":"user","level":"debug","appenders":["console","file"]}'
    )


def _print_node_logs_on_failure(item, call):
    """Print hived logs when a test fails for debugging."""
    # Only print on actual test call failures (not setup/teardown)
    if call.when != "call" or call.excinfo is None:
        return

    # Find the test's generated directory
    # Test directories follow pattern: generated_during_<test_file>/<test_name>/
    test_file = Path(item.fspath).stem  # e.g., test_p2p_sync_in_mirrornet
    generated_base = Path(item.fspath).parent / f"generated_during_{test_file}"

    # Handle parametrized tests - test name might include parameters
    test_name = item.name
    # Convert test_name like "test_p2p_sync[disabled_indexes]" to directory pattern
    # The directory uses "with_parameters_" prefix for parametrized tests
    if "[" in test_name:
        base_name = test_name.split("[")[0]
        param_part = test_name.split("[")[1].rstrip("]")
        test_dir_name = f"{base_name}_with_parameters_{param_part}"
    else:
        test_dir_name = test_name

    test_dir = generated_base / test_dir_name

    logs = _find_node_logs(test_dir)
    if not logs:
        tt.logger.warning(f"No node logs found in {test_dir}")
        return

    tt.logger.info(f"\n{'='*60}")
    tt.logger.info(f"HIVED LOGS FOR FAILED TEST: {test_name}")
    tt.logger.info(f"{'='*60}")

    for node_name, log_file in logs:
        tt.logger.info(f"\n--- {node_name} ({log_file}) ---")
        try:
            content = log_file.read_text()
            # Print last 200 lines to avoid overwhelming output
            lines = content.splitlines()
            if len(lines) > 200:
                tt.logger.info(
                    f"[...truncated, showing last 200 of {len(lines)} lines...]"
                )
                lines = lines[-200:]
            for line in lines:
                tt.logger.info(line)
        except Exception as e:
            tt.logger.warning(f"Failed to read log: {e}")

    tt.logger.info(f"{'='*60}\n")


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Hook to print node logs when a test fails."""
    outcome = yield
    report = outcome.get_result()

    if report.failed:
        _print_node_logs_on_failure(item, call)


def pytest_addoption(parser):
    parser.addoption(
        "--block-log-dir-path",
        action="store",
        type=str,
        help="specifies path of block_log",
    )
    parser.addoption(
        "--snapshot-path", action="store", type=str, help="specifies path of snapshot"
    )
    parser.addoption(
        "--mirrornet-block-count",
        action="store",
        type=int,
        default=1_000_000,
        help="Number of blocks to use for mirrornet tests (default: 1000000). Use 5000000 for full coverage.",
    )


@pytest.fixture
def mirrornet_block_count(request: pytest.FixtureRequest) -> int:
    """Return the configured block count for mirrornet tests.

    Default is 1M blocks for faster tests. Use --mirrornet-block-count=5000000 for full coverage.
    """
    return request.config.getoption("--mirrornet-block-count")


@pytest.fixture
def block_log_5m(request: pytest.FixtureRequest) -> tt.BlockLog:
    block_log_dir_path = Path(request.config.getoption("--block-log-dir-path"))
    assert (
        block_log_dir_path / tt.BlockLog.MONO_BLOCK_FILE_NAME
    ).exists(), f"block_log file does not exists in: {block_log_dir_path.as_posix()}"
    block_log = tt.BlockLog(block_log_dir_path, mode="monolithic")
    assert (
        len(block_log.block_files) > 0
    ), f"block log files does not exists in: {block_log_dir_path.as_posix()}"
    return block_log


@pytest.fixture
def block_log(block_log_5m, mirrornet_block_count, tmp_path) -> tt.BlockLog:
    """Return a block log truncated to the configured block count.

    If mirrornet_block_count >= 5M, returns the original block_log_5m.
    Otherwise, truncates to the requested size.
    """
    if mirrornet_block_count >= 5_000_000:
        return block_log_5m
    output_dir = tmp_path / "truncated_block_log"
    output_dir.mkdir(exist_ok=True)
    return block_log_5m.truncate(output_dir, mirrornet_block_count)


@pytest.fixture
def snapshot_path(request):
    return request.config.getoption("--snapshot-path")


@pytest.fixture
def mirrornet_snapshot(snapshot_path, block_log_5m) -> tt.Snapshot:
    """
    Snapshot configured to use local block_log instead of NFS.

    The snapshot itself is on NFS (shared between CI jobs), but the block_log
    is available locally on all runners. This avoids slow NFS copies of the
    block_log when loading the snapshot.
    """
    return tt.Snapshot(Path(snapshot_path), block_log_5m)


@pytest.fixture
def mirrornet_witness_node():
    witness_node = tt.RawNode()
    witness_node.config.witness = WITNESSES_5M
    witness_node.config.private_key = SKELETON_KEY
    witness_node.config.shared_file_size = "2G"
    witness_node.config.enable_stale_production = True
    witness_node.config.required_participation = 0
    witness_node.config.plugin.append("database_api")
    witness_node.config.plugin.append("witness")
    witness_node.config.plugin.append("account_by_key")
    apply_block_log_type_to_monolithic_workaround(witness_node)
    _configure_hived_file_logging(witness_node)
    return witness_node


@pytest.fixture
def witness_node_with_haf(haf_node):
    haf_node.config.shared_file_size = "2G"
    haf_node.config.witness = WITNESSES_5M
    haf_node.config.private_key = SKELETON_KEY
    haf_node.config.shared_file_size = "2G"
    haf_node.config.enable_stale_production = True
    haf_node.config.required_participation = 0
    _configure_hived_file_logging(haf_node)
    yield haf_node


@pytest.fixture
def haf_node(haf_node):
    haf_node.config.shared_file_size = "2G"
    _configure_hived_file_logging(haf_node)
    yield haf_node
