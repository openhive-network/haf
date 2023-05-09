import test_tools as tt

import pytest


@pytest.mark.mirrornet
def test_simple(tmp_path, block_log_5m_path):
    witness_node = tt.WitnessNode()
    block_log_5m = tt.BlockLog(block_log_5m_path)
    block_log_100k = block_log_5m.truncate(tmp_path, 100000, False)

    witness_node.run(replay_from=block_log_100k, wait_for_live=False)
