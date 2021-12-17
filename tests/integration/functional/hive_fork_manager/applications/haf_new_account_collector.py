#!/usr/bin/env python3
import pexpect
import sys
import os

sys.path.append(os.path.dirname(__file__) + "/../../../../../src/applications/utils")

from haf_sql import haf_sql

def test_new_account( path ):
    print( "Test test_new_account {}".format( path ) )

    _db_url = "postgresql://alice:test@127.0.0.1:5432/psql_tools_test_db"

    application = pexpect.spawn( path + " --url {} --range-blocks 2 --massive-threshold 1".format(_db_url) )
    application.logfile = sys.stdout.buffer
    application.timeout = 1

    application.expect( "Values in range blocks have NULL" )

    application.kill( 0 )

    _app_schema   = "new_accounts"
    _app_context  = _app_schema + "_app"
    _sql          = haf_sql(_app_context, _db_url)

    _query = "SELECT count(*) FROM {}.creation_history".format(_app_schema)

    _expected = 0
    _result   = _sql.exec_query_one(_query)
    assert _expected == _result, "incorrect number created accounts: expected {} result: {}".format(_expected, _result)

if __name__ == '__main__':
    test_new_account( sys.argv[ 1 ] + "/haf_new_account_collector.py" )
