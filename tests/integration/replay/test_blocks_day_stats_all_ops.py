import os
import pandas as pd
from pathlib import Path

from test_tools import logger


def test_blocks_day_stats():
    logger.info(f'Start test_blocks_day_stats')

    if "DB_URL" not in os.environ:
        raise Exception('DB_URL environment variable not set')
    url = os.environ.get('DB_URL')
       
    block_day_all_ops_database = pd.read_sql_table('block_day_stats_all_ops_view', url, schema='hive')
    pattern_path = Path(__file__).with_name('block_day_stats_all_ops_view.pat.csv')
    with pattern_path.open('r') as file:
        block_day_all_ops_file = pd.read_csv(file)

    try:
        pd.testing.assert_frame_equal(block_day_all_ops_database, block_day_all_ops_file)
    except:
        block_day_all_ops_database.to_csv('block_day_stats_all_ops_view.out.csv', index=False)
        raise
