#!/usr/bin/env python
import os
import pandas as pd


if __name__ == "__main__":
    if "DB_URL" not in os.environ:
        raise Exception('DB_URL environment variable not set')

    url = os.environ.get('DB_URL')

    block_day_database = pd.read_sql_table('block_day_stats_view', url, schema='hive')
    block_day_database.to_csv('block_day_stats_view.pat.csv', index=False)

    block_day_all_database = pd.read_sql_table('block_day_stats_all_ops_view', url, schema='hive')
    block_day_all_database.to_csv('block_day_stats_all_ops_view.pat.csv', index=False)
