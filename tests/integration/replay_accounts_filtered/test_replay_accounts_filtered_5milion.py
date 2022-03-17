from pathlib import Path
import os
import sqlalchemy
from sqlalchemy.pool import NullPool
from sqlalchemy.orm import sessionmaker

from test_tools import logger
from tables import EventsQueue, Blocks, Operations, Transactions, TransactionsMultisig, Accounts, AccountOperations


BLOCK_LOG_LENGTH = 5_000_000

BLOCKS_COUNT = 5_000_000
OPERATIONS_COUNT = 77_129 
TRANSACTIONS_COUNT = 35_100
TRANSACTIONS_MULTISIG_COUNT = 2
ACCOUNTS_COUNT = 196
ACCOUNT_OPERATIONS_COUNT = 78_126


def test_replay_accounts_filtered_5milion():
    logger.info(f'Start test_replay_accounts_filtered_5milion')

    if "DB_URL" not in os.environ:
        raise Exception('DB_URL environment variable not set')

    url = os.environ.get('DB_URL')

    engine = sqlalchemy.create_engine(url, echo=False, poolclass=NullPool)
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
