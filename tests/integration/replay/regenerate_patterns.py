#!/usr/bin/env python3
import json
import os
import pandas as pd
from pathlib import Path

from local_tools import get_rows_count


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


    actual_rows_count = get_rows_count(url)
    with open(patterns_root.joinpath('haf_rows_count.pat.json'), 'w') as f:
        json.dump(actual_rows_count, f, indent=2, sort_keys=True)
