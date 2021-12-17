#!/usr/bin/env python3
import pexpect
import sys

def test_account_creation_fee_threads( path ):
    print( "Test test_account_creation_fee_threads {}".format( path ) )
    application = pexpect.spawn( path + " --url postgresql://alice:test@127.0.0.1:5432/psql_tools_test_db --range-blocks 4 --threads 2" )
    application.logfile = sys.stdout.buffer
    application.timeout = 1

    application.expect( "Values in range blocks have NULL" )

    application.kill( 0 )

    #TODO: to add some SELECT's

if __name__ == '__main__':
    test_account_creation_fee_threads( sys.argv[ 1 ] + "/haf_account_creation_fee_follower_threads.py" )