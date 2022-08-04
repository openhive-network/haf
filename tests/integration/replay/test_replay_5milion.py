import json
from pathlib import Path
import os
import unittest

from local_tools import get_rows_count

import test_tools as tt


def test_replay_5milion():
    tt.logger.info(f'Start test_replay_5milion')

    if not os.environ.get('DB_URL'):
        raise Exception('DB_URL environment variable not set')
    if not os.environ.get('PATTERNS_PATH'):
        raise Exception('PATTERNS_PATH environment variable not set')

    url = os.environ.get('DB_URL')
    patterns_root = Path(os.environ.get('PATTERNS_PATH'))
    with open(patterns_root.joinpath('haf_rows_count.pat.json')) as f:
        expected_rows_count = json.load(f)

    actual_rows_count = get_rows_count(url)

    tt.logger.info(f'actual_rows_count: {actual_rows_count}')
    tt.logger.info(f'expected_rows_count: {expected_rows_count}')
    try:
        case = unittest.TestCase()
        case.assertDictEqual(actual_rows_count, expected_rows_count)
    except:
        with open(patterns_root.joinpath('haf_rows_count.out.json'), 'w') as f:
            json.dump(actual_rows_count, f, indent=2, sort_keys=True)
        raise
