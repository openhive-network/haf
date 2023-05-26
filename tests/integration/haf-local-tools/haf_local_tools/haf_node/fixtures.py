from typing import Dict
import pytest
from pytest import StashKey, CollectReport
from sqlalchemy_utils import drop_database

from haf_local_tools.haf_node import HafNode

phase_report_key = StashKey[Dict[str, CollectReport]]()


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    # execute all other hooks to obtain the report object
    outcome = yield
    rep = outcome.get_result()

    # store test results for each phase of a call, which can
    # be "setup", "call", "teardown"
    item.stash.setdefault(phase_report_key, {})[rep.when] = rep


@pytest.fixture
def haf_node(request):
    """
    This fixture extends the functionality of haf_node by adding the ability
    to remove the HAF database only in tests that have completed successfully.
    The implementation was taken from the documentation of the pytest module.
    """
    haf_node =  HafNode(keep_database=True)
    drop_database_if_test_pass = True
    yield haf_node
    if drop_database_if_test_pass:
        haf_node.close()
        report = request.node.stash[phase_report_key]
        if not report["call"].failed:
            drop_database(haf_node.database_url)
