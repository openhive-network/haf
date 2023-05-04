import pytest


def pytest_addoption(parser):
    parser.addoption("--block-log-path", action="store", type=str, help='specifies path of block_log')


@pytest.fixture
def block_log_5m_path(request):
    return request.config.getoption("--block-log-path")
