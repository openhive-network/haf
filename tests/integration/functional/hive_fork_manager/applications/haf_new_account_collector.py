#!/usr/bin/env python3
import pexpect
import sys

def test_new_account( path ):
    print( "Test test_new_account {}".format( path ) )
    application = pexpect.spawn( path + " --url postgresql://alice:test@127.0.0.1:5432/psql_tools_test_db --range-blocks 2 --massive-threshold 1" )
    application.logfile = sys.stdout.buffer
    application.timeout = 1

    application.expect( "Values in range blocks have NULL" )

    application.kill( 0 )

    #TODO: to add some SELECT's

if __name__ == '__main__':
    test_new_account( sys.argv[ 1 ] + "/haf_new_account_collector.py" )