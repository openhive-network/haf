import test_tools as tt

from local_tools import make_fork, wait_for_irreversible_progress, prepare_networks


START_TEST_BLOCK = 108


def test_blocks_reversible(prepared_networks_and_database):
    tt.logger.info(f'Start test_blocks_reversible')

    # GIVEN
    networks, session, Base = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')
    blocks_reversible = Base.classes.blocks_reversible

    # WHEN
    prepare_networks(networks)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    after_fork_block = make_fork(networks)

    # THEN
    irreversible_block_num, head_block_number = wait_for_irreversible_progress(node_under_test, after_fork_block+1)

    blks = session.query(blocks_reversible).order_by(blocks_reversible.num).all()
    block_nums_reversible = [block.num for block in blks]
    assert sorted(block_nums_reversible) == [i for i in range(irreversible_block_num, head_block_number)]
