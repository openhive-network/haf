from pathlib import Path
import time
import pytest

import test_tools as tt

from haf_local_tools.system.haf.mirrornet.constants import SKELETON_KEY, WITNESSES_5M
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround


# Timing instrumentation for mirrornet tests
@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_protocol(item, nextitem):
    """Log timing for each test phase."""
    start = time.time()
    tt.logger.info(f"[TIMING] Starting test: {item.name}")
    yield
    elapsed = time.time() - start
    tt.logger.info(f"[TIMING] Completed test: {item.name} in {elapsed:.2f}s")


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
    start = time.time()
    tt.logger.info(f"[TIMING] Creating mirrornet_snapshot fixture from: {snapshot_path}")
    snapshot = tt.Snapshot(Path(snapshot_path), block_log_5m)
    elapsed = time.time() - start
    tt.logger.info(f"[TIMING] mirrornet_snapshot fixture created in {elapsed:.2f}s")
    return snapshot


@pytest.fixture
def mirrornet_witness_node():
    start = time.time()
    tt.logger.info("[TIMING] Creating mirrornet_witness_node fixture")
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
    elapsed = time.time() - start
    tt.logger.info(f"[TIMING] mirrornet_witness_node fixture created in {elapsed:.2f}s")
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
    start = time.time()
    tt.logger.info("[TIMING] Configuring haf_node fixture")
    haf_node.config.shared_file_size = "2G"
    elapsed = time.time() - start
    tt.logger.info(f"[TIMING] haf_node fixture configured in {elapsed:.2f}s")
    yield haf_node
