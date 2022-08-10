#!/usr/bin/env python3
import os
import pandas as pd
from pathlib import Path

'''
To quickly generate haf_rows_count.json use following query:

SELECT json_build_object(
    'BLOCK_LOG_LENGTH', 5000000,
    'BLOCKS_COUNT', (SELECT COUNT(*) FROM hive.blocks),
    'OPERATIONS_COUNT', (SELECT COUNT(*) FROM hive.operations),
    'TRANSACTIONS_COUNT', (SELECT COUNT(*) FROM hive.transactions),
    'TRANSACTIONS_MULTISIG_COUNT', (SELECT COUNT(*) FROM hive.transactions_multisig),
    'ACCOUNTS_COUNT', (SELECT COUNT(*) FROM hive.accounts),
    'ACCOUNT_OPERATIONS_COUNT', (SELECT COUNT(*) FROM hive.account_operations)
);

'''


if __name__ == "__main__":
    if not os.environ.get('DB_URL'):
        raise Exception('DB_URL environment variable not set')
    if not os.environ.get('PATTERNS_PATH'):
        raise Exception('PATTERNS_PATH environment variable not set')

    url = os.environ.get('DB_URL')
    patterns_root = Path(os.environ.get('PATTERNS_PATH'))

    block_day_database = pd.read_sql_table('block_day_stats_view', url, schema='hive')
    block_day_database.to_csv(patterns_root.joinpath('block_day_stats_view.pat.csv'), index=False)

    block_day_all_database = pd.read_sql_table('block_day_stats_all_ops_view', url, schema='hive')
    block_day_all_database.to_csv(patterns_root.joinpath('block_day_stats_all_ops_view.pat.csv'), index=False)
