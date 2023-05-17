import pytest
from sqlalchemy_utils import drop_database

import test_tools as tt

from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf.mirrornet.constants import SKELETON_KEY, WITNESSES_5M

from haf_local_tools.haf_node.fixtures import phase_report_key


def pytest_addoption(parser):
    parser.addoption(
        "--block-log-path", action="store", type=str, help="specifies path of block_log"
    )


@pytest.fixture
def block_log_5m_path(request):
    return request.config.getoption("--block-log-path")


@pytest.fixture
def mirrornet_witness_node():
    witness_node = tt.RawNode()
    witness_node.config.witness = WITNESSES_5M
    witness_node.config.private_key = SKELETON_KEY
    witness_node.config.shared_file_size = "2G"
    witness_node.config.enable_stale_production = True
    witness_node.config.required_participation = 0
    witness_node.config.plugin = "database_api witness"
    return witness_node


@pytest.fixture
def witness_node_with_haf(request):
    """
    This fixture extends the functionality of haf_node by adding the ability
    to remove the HAF database only in tests that have completed successfully.
    The implementation was taken from the documentation of the pytest module.
    """
    haf_node = HafNode(keep_database=True)
    haf_node.config.shared_file_size = "2G"
    haf_node.config.witness = WITNESSES_5M
    haf_node.config.private_key = SKELETON_KEY
    haf_node.config.shared_file_size = "2G"
    haf_node.config.enable_stale_production = True
    haf_node.config.required_participation = 0
    drop_database_if_test_pass = True
    yield haf_node
    if drop_database_if_test_pass:
        report = request.node.stash[phase_report_key]
        if not report["call"].failed:
            drop_database(haf_node.database_url)
