#!/usr/bin/env python3
import pexpect
import sys

def test_memo( path ):
    print( "Test test_memo {}".format( path ) )
    application = pexpect.spawn( path + " --url postgresql://alice:test@127.0.0.1:5432/psql_tools_test_db --searched-item bittrex" )
    application.logfile = sys.stdout.buffer
    application.timeout = 1

    application.expect( "Values in range blocks have NULL" )

    application.kill( 0 )

    #TODO: to add some SELECT's

if __name__ == '__main__':
    test_memo( sys.argv[ 1 ] + "/haf_memo_scanner.py" )