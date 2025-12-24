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


def log_timing(test_name: str, step: str, duration: float):
    """Log timing to shared file (thread/process safe)."""
    line = f"{test_name}|{step}|{duration:.2f}s\n"
    with open(TIMING_FILE, "a") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        f.write(line)
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def pytest_configure(config):
    """Clear timing file at start of test session."""
    if TIMING_FILE.exists():
        TIMING_FILE.unlink()


def pytest_sessionfinish(session, exitstatus):
    """Print collected timing data at end of test session."""
    if not TIMING_FILE.exists():
        return

    print("\n" + "=" * 70)
    print("MIRRORNET TEST TIMING REPORT")
    print("=" * 70)

    # Group timing by test
    timing_data = {}
    with open(TIMING_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("|")
            if len(parts) == 3:
                test_name, step, duration = parts
                if test_name not in timing_data:
                    timing_data[test_name] = []
                timing_data[test_name].append((step, duration))

    for test_name in sorted(timing_data.keys()):
        print(f"\n{test_name}:")
        for step, duration in timing_data[test_name]:
            print(f"  {step}: {duration}")

    print("\n" + "=" * 70)


# Timing instrumentation for mirrornet tests
@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_protocol(item, nextitem):
    """Log timing for each test phase."""
    start = time.time()
    yield
    elapsed = time.time() - start
    log_timing(item.name, "TOTAL", elapsed)


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
