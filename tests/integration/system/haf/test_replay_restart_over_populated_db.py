import os
import re
import signal
import subprocess

import pytest

import test_tools as tt

from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    create_and_run_init_node_with_retry,
    prepare_and_send_transactions,
)

GUARD_MESSAGE = re.compile(
    r"HAF database irreversible top block (\d+) is above hived head block (\d+)"
)
COUNTED_TABLES = ("blocks", "operations", "account_operations")


def row_counts(haf_node: HafNode) -> dict[str, int]:
    return {
        table: haf_node.query_one(f"SELECT COUNT(*) FROM hafd.{table}")
        for table in COUNTED_TABLES
    }


def hived_log(haf_node: HafNode) -> str:
    log: str = (haf_node.directory / "stderr.log").read_text(errors="replace")
    return log


def replay_to(haf_node: HafNode, init_node: tt.InitNode, block_num: int) -> None:
    haf_node.run(
        replay_from=init_node.block_log,
        stop_at_block=block_num,
        wait_for_live=False,
    )


def test_force_replay_over_populated_database_is_refused(haf_node: HafNode) -> None:
    init_node = create_and_run_init_node_with_retry()
    _, transaction_1 = prepare_and_send_transactions(init_node)
    stop_block = transaction_1["block_num"]

    replay_to(haf_node, init_node, stop_block)
    haf_node.wait_for_transaction_in_database(transaction_1)
    assert_are_blocks_sync_with_haf_db(haf_node, stop_block)
    haf_node.close()

    top_irreversible_block = haf_node.query_one("SELECT MAX(num) FROM hafd.blocks")
    counts_before = row_counts(haf_node)
    assert counts_before["account_operations"] > 0

    # exit_at_block makes the run blocking: a start the guard did not refuse replays to it and exits 0
    with pytest.raises(tt.exceptions.FailedToStartExecutableError) as refused:
        haf_node.run(
            replay_from=init_node.block_log,
            exit_at_block=stop_block,
            arguments=tt.NodeArguments(force_replay=True),
        )
    process_error = refused.value.__cause__
    assert isinstance(process_error, subprocess.CalledProcessError)
    # hived's main returns -1 when startup throws; a crash is a negative status (killed by a signal) or 128 + signal through a shell
    assert process_error.returncode == 255

    log = hived_log(haf_node)
    guard = GUARD_MESSAGE.search(log)
    assert guard is not None, "hived did not log the full-mode hive.connect guard"
    assert "exited cleanly" in log, "hived did not shut down in order after the refusal"
    assert int(guard.group(1)) == top_irreversible_block
    assert int(guard.group(2)) == 0

    assert row_counts(haf_node) == counts_before
    assert (
        haf_node.query_one("SELECT MAX(num) FROM hafd.blocks") == top_irreversible_block
    )


def test_replay_blockchain_continues_from_stopped_replay(haf_node: HafNode) -> None:
    init_node = create_and_run_init_node_with_retry()
    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)
    first_stop_block = transaction_0["block_num"]
    second_stop_block = transaction_1["block_num"]

    replay_to(haf_node, init_node, first_stop_block)
    haf_node.wait_for_transaction_in_database(transaction_0)
    assert_are_blocks_sync_with_haf_db(haf_node, first_stop_block)
    haf_node.close()

    replay_to(haf_node, init_node, second_stop_block)
    haf_node.wait_for_transaction_in_database(transaction_1)

    log = hived_log(haf_node)
    assert f"Resume of replaying. Last applied block: {first_stop_block}" in log
    assert GUARD_MESSAGE.search(log) is None
    assert_are_blocks_sync_with_haf_db(haf_node, second_stop_block)
    assert haf_node.query_one("SELECT MAX(num) FROM hafd.blocks") == second_stop_block


def test_replay_blockchain_after_sigkill_restarts(haf_node: HafNode) -> None:
    """
    Kills hived with SIGKILL once a replay stopped at block N, then recovers the way an operator would:
    restarting on the same data directory and database with --replay-blockchain, to a later block M.

    Observed: hived starts and syncs. The state survives the kill: hived resumes the replay from block N
    ("Resume of replaying. Last applied block: N"), logs neither its own inconsistent-state error nor the
    hive.connect guard, and the database ends in sync with the node at block M.
    """
    init_node = create_and_run_init_node_with_retry()
    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)
    first_stop_block = transaction_0["block_num"]
    second_stop_block = transaction_1["block_num"]

    replay_to(haf_node, init_node, first_stop_block)
    haf_node.wait_for_transaction_in_database(transaction_0)
    assert_are_blocks_sync_with_haf_db(haf_node, first_stop_block)

    os.kill(haf_node.pid, signal.SIGKILL)
    tt.Time.wait_for(lambda: not haf_node.is_running(), timeout=30)
    haf_node.close()

    replay_to(haf_node, init_node, second_stop_block)
    haf_node.wait_for_transaction_in_database(transaction_1)

    log = hived_log(haf_node)
    assert f"Resume of replaying. Last applied block: {first_stop_block}" in log
    assert GUARD_MESSAGE.search(log) is None
    assert_are_blocks_sync_with_haf_db(haf_node, second_stop_block)
    assert haf_node.query_one("SELECT MAX(num) FROM hafd.blocks") == second_stop_block
