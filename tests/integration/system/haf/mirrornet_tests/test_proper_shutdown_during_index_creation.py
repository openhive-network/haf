import os
import signal
import time

import pytest

import test_tools as tt

from haf_local_tools.system.haf import connect_nodes
from haf_local_tools.system.haf.mirrornet.constants import CHAIN_ID, SKELETON_KEY


@pytest.mark.mirrornet
@pytest.mark.parametrize("signal_type", [signal.SIGINT, signal.SIGKILL])
def test_proper_shutdown_during_index_creation(mirrornet_witness_node, haf_node, block_log_5m, tmp_path, signal_type):
    """
    Related to: https://gitlab.syncad.com/hive/hive/-/issues/794
    """
    block_log_1m = block_log_5m.truncate(tmp_path, 1000000)
    mirrornet_witness_node.run(
        replay_from=block_log_1m,
        time_control=tt.StartTimeControl(start_time="head_block_time"),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    head_block_time = mirrornet_witness_node.get_head_block_time()

    connect_nodes(mirrornet_witness_node, haf_node)

    haf_node.run(
        replay_from=block_log_1m,
        time_control=tt.StartTimeControl(start_time=head_block_time),
        exit_before_synchronization=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )

    head_block_time = mirrornet_witness_node.get_head_block_time()

    haf_node.run(
        time_control=tt.StartTimeControl(start_time=head_block_time),
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
        wait_for_live=False,
    )
    haf_node_pid = haf_node._RunnableNodeHandle__implementation.pid

    search_timeout = 60 # seconds
    start_time = time.time()

    with open(str(haf_node.directory / "stderr_1.log"), "r") as f:
        f.seek(0, 0)

        while time.time() - start_time < search_timeout:
            new_data = f.read()
            if not new_data:
                time.sleep(0.1)
                continue

            if "PROFILE: Entering LIVE sync, creating indexes/constraints as needed" in new_data:
                os.kill(haf_node_pid, signal_type)
                tt.logger.info(f"Sent {signal_type.name} to haf_node on pid: {haf_node_pid}!")

                time.sleep(10) # time to gently exit haf node

                f.seek(0, 0)
                full_log = f.read()
                if "exited cleanly" in full_log:
                    tt.logger.info(f"Haf node exited cleanly after {signal_type.name}.")
                    break
                else:
                    pytest.fail(f"Haf node did not exit cleanly after {signal_type.name}.")
        else:
            pytest.fail(f"Phase `exited cleanly` not found in log within {search_timeout} seconds")
