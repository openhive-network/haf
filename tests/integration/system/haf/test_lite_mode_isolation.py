from pathlib import Path

import pytest


LATER_TESTS = '''
import gc

from test_tools.__private.process.node_config import NodeConfig

lite_mode_config_ids = []


def saved_config(config, directory):
    directory.mkdir()
    config.save(directory)
    return (directory / "config.ini").read_text()


def test_lite_mode_node(lite_mode_configs, tmp_path):
    config = NodeConfig.default()
    lite_mode_configs.append(config)
    lite_mode_config_ids.append(id(config))

    assert "psql-lite-mode = 1" in saved_config(config, tmp_path / "lite")
    assert "psql-lite-mode" not in saved_config(NodeConfig.default(), tmp_path / "other")


def test_later_node(tmp_path):
    gc.collect()
    configs = [NodeConfig.default() for _ in range(1000)]
    # Configs that took over a freed lite-mode config's address come first: an id()-keyed registry would match them.
    configs.sort(key=lambda config: id(config) not in lite_mode_config_ids)

    for number, config in enumerate(configs[:10]):
        assert "psql-lite-mode" not in saved_config(config, tmp_path / str(number))
'''


def test_lite_mode_ends_with_its_test(pytester: pytest.Pytester) -> None:
    """Only the test that registers a node config for lite mode saves it with psql-lite-mode: a node config
    of a later test in the same process does not, even one at the freed config's address."""
    pytester.makeconftest((Path(__file__).parents[2] / "conftest.py").read_text())
    pytester.makepyfile(LATER_TESTS)

    result = pytester.runpytest_subprocess("-p", "no:xdist", "-p", "no:cacheprovider")

    result.assert_outcomes(passed=2)
