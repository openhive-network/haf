from pathlib import Path
import pytest

import test_tools as tt

from haf_local_tools.system.haf.mirrornet.constants import SKELETON_KEY, WITNESSES_5M
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround


def pytest_addoption(parser):
    parser.addoption(
        "--block-log-dir-path", action="store", type=str, help="specifies path of block_log"
    )
    parser.addoption(
        "--snapshot-path", action="store", type=str, help="specifies path of snapshot"
    )


@pytest.fixture
def block_log_5m(request: pytest.FixtureRequest) -> tt.BlockLog:
    block_log_dir_path = Path(request.config.getoption("--block-log-dir-path"))
    assert (block_log_dir_path / tt.BlockLog.MONO_BLOCK_FILE_NAME).exists(), f"block_log file does not exists in: {block_log_dir_path.as_posix()}"
    block_log = tt.BlockLog(block_log_dir_path, mode="monolithic")
    assert len(block_log.block_files) > 0, f"block log files does not exists in: {block_log_dir_path.as_posix()}"
    return block_log


@pytest.fixture
def snapshot_path(request):
    return request.config.getoption("--snapshot-path")


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
