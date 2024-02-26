from sqlalchemy import cast
from sqlalchemy.dialects.postgresql import JSONB

import test_tools as tt

from haf_local_tools import get_head_block, get_irreversible_block, wait_for_irreversible_progress, wait_for_irreversible_in_database
from haf_local_tools.tables import AccountsView, Blocks, BlocksView, Transactions, Operations


START_TEST_BLOCK = 115


def __is_irreversible_block_in_database(self, block_num: int) -> bool:
    sql = "SELECT exists(SELECT 1 FROM hive.blocks WHERE num = :block_num);"
    return self.query_one(sql, block_num=block_num)


def display_blocks_information(node):
    h_b = get_head_block(node)
    i_b = get_irreversible_block(node)
    tt.logger.info(f'head_block: {h_b} irreversible_block: {i_b}')
    return h_b, i_b


def test_live_sync_from_115(prepared_networks_and_database_12_8_from_115):
    tt.logger.info(f'Start test_live_sync_from_115')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8_from_115
    witness_node = networks_builder.networks[0].node('WitnessNode0')
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=witness_node)
    wallet.api.transfer('initminer', 'initminer', tt.Asset.Test(1000), 'dummy transfer operation')
    transaction_block_num, _ = display_blocks_information(node_under_test)

    # THEN
    # an irreversible block with transaction shall be dumped
    wait_for_irreversible_in_database(session, transaction_block_num)
    blks_in_database = session.query(Blocks).order_by(Blocks.num).all()
    block_nums_in_database = [block.num for block in blks_in_database]
    head_block = get_head_block(node_under_test)

    assert head_block >= transaction_block_num, "Head block lower than irreversible block"


    # We have 109 irreversible blocks already synced, and now we can have two situations:
    # 1. hived will send end_of_syncing notification->serializer will move from START to LIVE state
    #   ,database will be initialized and the next block (110) will be the first synced.
    # 2. hived will process a block and pre_apply/post_apply block notification will be sent.
    #   Here the first processed block will be discarded because it is less than psql-first-block (110<115),
    #   serializer will move from START to WAIT state. After processing a block, hived will send
    #   end_of_syncing notification-> serializer will move from WAIT to LIVE state, database will be initialized
    #   and the next block (111) will be the first synced.
    # For the test purpose it doesn't matter which situation will happen, it is
    # only important that blocks less than 110 are not dumped, and dumping
    # blocks is started from the block less than 115, during entering the LIVE state
    # before reaching psql-first-block limit.
    assert sorted(block_nums_in_database)[:2] == [i for i in [110,111]] \
           or sorted(block_nums_in_database)[:2] == [i for i in [111,112]] # situation 1 or situation 2

    # haf has always subset or full set of hive blocks, because WAL is almost always behind hived
    # if we get irreversible block for hived, it means after some time it will be added to irreversible blocks of hfm

    account_count = session.query(AccountsView).count()
    assert account_count == 27

    session.query(Transactions).filter(Transactions.block_num == transaction_block_num).one()

    ops = session.query(Operations).add_columns(cast(Operations.body_binary, JSONB).label('body'), Operations.block_num).filter(Operations.block_num == transaction_block_num).all()
    types = [op.body['type'] for op in ops]

    assert 'transfer_operation' in types
    assert 'producer_reward_operation' in types
