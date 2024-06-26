import sqlalchemy

import test_tools as tt

from haf_local_tools.system.haf import prepare_and_send_transactions


def get_truncated_block_log(node, block_count: int):
    output_block_log_path = tt.context.get_current_directory() / "block_log"
    output_block_log_path.unlink(missing_ok=True)
    output_block_log_artifacts_path = (tt.context.get_current_directory() / "block_log.artifacts")
    output_block_log_artifacts_path.unlink(missing_ok=True)
    block_log = node.block_log.truncate(tt.context.get_current_directory(), block_count)
    return block_log


def test_replay_error(haf_node):
    """
    Check that an exception raised during replay in worker thread is handled correctly.
    The node should catch the exception, kill all the workers and exit cleanly.
    """
    # generate some operations to be replayed
    init_node = tt.InitNode()
    init_node.run()
    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)
    init_node.close()
    block_log = get_truncated_block_log(init_node, transaction_0["block_num"] + 1)

    # Alter operations table so that worker thread raises an exception when storing data in it
    session = haf_node.session
    session.execute(sqlalchemy.text('ALTER TABLE hive.operations ADD CONSTRAINT check_length CHECK (octet_length(body_binary) <= 21)'))
    haf_node.run(
        replay_from=block_log,
        exit_at_block=30,
    )
