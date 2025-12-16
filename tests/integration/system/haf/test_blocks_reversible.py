import test_tools as tt
from sqlalchemy.sql import text

from haf_local_tools import make_fork, wait_for_irreversible_progress


START_TEST_BLOCK = 108


def test_blocks_reversible(prepared_networks_and_database_12_8):
    tt.logger.info(f'Start test_blocks_reversible')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    after_fork_block = make_fork(networks_builder.networks)

    # THEN
    irreversible_block_num, head_block_number = wait_for_irreversible_progress(node_under_test, after_fork_block+1)

    # Query reversible blocks from unified blocks table
    # Reversible blocks have block_num > consistent_block (from hive_state)
    result = session.execute(text("""
        SELECT DISTINCT hafd.block_id_to_num(b.block_id) as num
        FROM hafd.blocks b, hafd.hive_state hs
        WHERE hafd.block_id_to_num(b.block_id) > hafd.block_id_to_num(hs.consistent_block)
        ORDER BY num
    """)).fetchall()
    block_nums_reversible = [row[0] for row in result]
    assert sorted(block_nums_reversible) == [i for i in range(irreversible_block_num, head_block_number)]
