#!/usr/bin/env python3
import pexpect
import sys
import os

sys.path.append(os.path.dirname(__file__) + "/../../../../../src/applications/utils")

from haf_sql import haf_sql

def test_account_creation_fee_threads( path ):
    print( "Test test_account_creation_fee_threads {}".format( path ) )

    _db_url = "postgresql://alice:test@127.0.0.1:5432/psql_tools_test_db"

    application = pexpect.spawn( path + " --url {} --range-blocks 4 --threads 2".format(_db_url) )
    application.logfile = sys.stdout.buffer
    application.timeout = 1

    application.expect( "Values in range blocks have NULL" )

    application.kill( 0 )

    _app_schema   = "fee_follower_threads"
    _app_context  = _app_schema + "_app"
    _sql          = haf_sql(_app_context, _db_url)

    _query = "SELECT count(*) FROM {}.fee_history".format(_app_schema)

    _expected = 0
    _result   = _sql.exec_query_one(_query)
    assert _expected == _result, "incorrect number found memos: expected {} result: {}".format(_expected, _result)

if __name__ == '__main__':
    test_account_creation_fee_threads( sys.argv[ 1 ] + "/haf_account_creation_fee_follower_threads.py" )