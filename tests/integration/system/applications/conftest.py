import pytest

from haf_local_tools.haf_node.fixtures import *

def pytest_configure(config):
    config.addinivalue_line("markers", "forking_only: test requires fork/reversible infrastructure")
