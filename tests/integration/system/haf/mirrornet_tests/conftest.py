from pathlib import Path
import tempfile
import time
import fcntl
import pytest

import test_tools as tt

from haf_local_tools.system.haf.mirrornet.constants import SKELETON_KEY, WITNESSES_5M
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround


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


def pytest_addoption(parser):
    parser.addoption("--block-log-dir-path", action="store", type=str, help="specifies path of block_log")
    parser.addoption("--snapshot-path", action="store", type=str, help="specifies path of snapshot")


@pytest.fixture
def block_log_5m(request: pytest.FixtureRequest) -> tt.BlockLog:
    block_log_dir_path = Path(request.config.getoption("--block-log-dir-path"))
    assert (
        block_log_dir_path / tt.BlockLog.MONO_BLOCK_FILE_NAME
    ).exists(), f"block_log file does not exists in: {block_log_dir_path.as_posix()}"
    block_log = tt.BlockLog(block_log_dir_path, mode="monolithic")
    assert len(block_log.block_files) > 0, f"block log files does not exists in: {block_log_dir_path.as_posix()}"
    return block_log


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
    return witness_node


@pytest.fixture
def witness_node_with_haf(haf_node):
    haf_node.config.shared_file_size = "2G"
    haf_node.config.witness = WITNESSES_5M
    haf_node.config.private_key = SKELETON_KEY
    haf_node.config.shared_file_size = "2G"
    haf_node.config.enable_stale_production = True
    haf_node.config.required_participation = 0
    yield haf_node


@pytest.fixture
def haf_node(haf_node):
    haf_node.config.shared_file_size = "2G"
    yield haf_node
