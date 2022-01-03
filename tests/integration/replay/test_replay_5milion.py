from pathlib import Path
import os
import sqlalchemy
from sqlalchemy.pool import NullPool
from sqlalchemy.orm import sessionmaker

from test_tools import logger, BlockLog
from tables import EventsQueue, Blocks, Operations, Transactions, TransactionsMultisig, Accounts, AccountOperations


BLOCK_LOG_LENGTH = 5_000_000

BLOCKS_COUNT = 5_000_000
OPERATIONS_COUNT = 19_752_015 
TRANSACTIONS_COUNT = 6_961_192
TRANSACTIONS_MULTISIG_COUNT = 450
ACCOUNTS_COUNT = 92_462
ACCOUNT_OPERATIONS_COUNT = 29_449_321


def test_replay_5milion(world, database):
    logger.info(f'Start test_replay_5milion')

    # TODO: use test_tools to run node instead running hived in gitlab shell executor
    # this must wait until mainnet nodes are supported in test tools

    # # GIVEN
    # session = database('postgresql:///haf_block_log')

    # node_under_test = world.create_api_node(name = 'NodeUnderTest')
    # node_under_test.config.shared_file_size = '8G'
    # node_under_test.config.plugin.append('sql_serializer')
    # node_under_test.config.psql_url = str(session.get_bind().url)

    # block_log_path = os.getenv('BLOCK_LOG_PATH') or './block_log'
    # block_log = BlockLog(None, block_log_path, include_index=False).truncate('block_log_5M', BLOCK_LOG_LENGTH)

    # # WHEN
    # node_under_test.run(replay_from=block_log, exit_before_synchronization=True)

    # THEN

    # TODO: use session provided by  instead when hived mainnet build is supported in test_tools
    engine = sqlalchemy.create_engine('postgresql:///haf_block_log', echo=False, poolclass=NullPool)
    session = sessionmaker(bind=engine)()

    event = session.query(EventsQueue).filter(EventsQueue.event == 'MASSIVE_SYNC').one()
    assert event.block_num == BLOCK_LOG_LENGTH

    blocks_count = session.query(Blocks).count()
    assert blocks_count == BLOCKS_COUNT

    operations_count = session.query(Operations).count()
    assert operations_count == OPERATIONS_COUNT

    transactions_count = session.query(Transactions).count()
    assert transactions_count == TRANSACTIONS_COUNT

    transactions_multisig_count = session.query(TransactionsMultisig).count()
    assert transactions_multisig_count == TRANSACTIONS_MULTISIG_COUNT

    account_count = session.query(Accounts).count()
    assert account_count == ACCOUNTS_COUNT

    account_operations_count = session.query(AccountOperations).count()
    assert account_operations_count == ACCOUNT_OPERATIONS_COUNT
