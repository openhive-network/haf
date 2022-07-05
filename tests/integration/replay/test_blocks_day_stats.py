import os
from pathlib import Path

import pandas as pd

import test_tools as tt


def test_blocks_day_stats():
    tt.logger.info(f'Start test_blocks_day_stats')

    if not os.environ.get('DB_URL'):
        raise Exception('DB_URL environment variable not set')
    if not os.environ.get('PATTERNS_PATH'):
        raise Exception('PATTERNS_PATH environment variable not set')

    url = os.environ.get('DB_URL')
    patterns_root = Path(os.environ.get('PATTERNS_PATH'))

    block_day_database = pd.read_sql_table('block_day_stats_view', url, schema='hive')
    pattern_path = patterns_root.joinpath('block_day_stats_view.pat.csv')
    with pattern_path.open('r') as file:
        block_day_file = pd.read_csv(file)

    try:
        if not( block_day_database.empty and block_day_file.empty ):
            pd.testing.assert_frame_equal(block_day_database, block_day_file)
    except:
        block_day_database.to_csv(patterns_root.joinpath('block_day_stats_view.out.csv'), index=False)
        raise
