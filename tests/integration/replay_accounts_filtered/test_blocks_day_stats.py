import os
import pandas as pd

from test_tools import logger


def test_blocks_day_stats():
    logger.info(f'Start test_blocks_day_stats')

    if "DB_URL" not in os.environ:
        raise Exception('DB_URL environment variable not set')
    url = os.environ.get('DB_URL')

    block_day_database = pd.read_sql_table('block_day_stats_view', url, schema='hive')
    with open('block_day_stats_view.pat.csv', 'r') as file:
        block_day_file = pd.read_csv(file)

    try:
        pd.testing.assert_frame_equal(block_day_database, block_day_file)
    except:
        block_day_database.to_csv('block_day_stats_view.out.csv', index=False)
        raise
