import json
from pathlib import Path
import os

import sqlalchemy
from sqlalchemy.pool import NullPool
from sqlalchemy.orm import sessionmaker

import test_tools as tt

from tables import EventsQueue, Blocks, Operations, Transactions, TransactionsMultisig, Accounts, AccountOperations


def test_replay_5milion():
    tt.logger.info(f'Start test_replay_5milion')

    if not os.environ.get('DB_URL'):
        raise Exception('DB_URL environment variable not set')
    if not os.environ.get('PATTERNS_PATH'):
        raise Exception('PATTERNS_PATH environment variable not set')

    url = os.environ.get('DB_URL')
    patterns_root = Path(os.environ.get('PATTERNS_PATH'))
    with open(patterns_root.joinpath('haf_rows_count.json')) as f:
        rows_count = json.load(f)

    engine = sqlalchemy.create_engine(url, echo=False, poolclass=NullPool)
    session = sessionmaker(bind=engine)()

    event = session.query(EventsQueue).filter(EventsQueue.event == 'MASSIVE_SYNC').one()
    assert event.block_num == rows_count['BLOCK_LOG_LENGTH']

    blocks_count = session.query(Blocks).count()
    assert blocks_count == rows_count['BLOCKS_COUNT']

    operations_count = session.query(Operations).count()
    assert operations_count == rows_count['OPERATIONS_COUNT']

    transactions_count = session.query(Transactions).count()
    assert transactions_count == rows_count['TRANSACTIONS_COUNT']

    transactions_multisig_count = session.query(TransactionsMultisig).count()
    assert transactions_multisig_count == rows_count['TRANSACTIONS_MULTISIG_COUNT']

    account_count = session.query(Accounts).count()
    assert account_count == rows_count['ACCOUNTS_COUNT']

    account_operations_count = session.query(AccountOperations).count()
    assert account_operations_count == rows_count['ACCOUNT_OPERATIONS_COUNT']
