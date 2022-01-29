#!/usr/bin/env python3
import pexpect
import sys

def test_example( example_path, pg_port ):
    print( "Test example {}".format( example_path ) )
    application = pexpect.spawn( example_path, [pg_port] )
    application.logfile = sys.stdout.buffer
    application.expect( "Blocks range \(1, 6\)" )
    application.expect( "Blocks range \(2, 6\)" )
    application.expect( "Blocks range \(3, 6\)" )
    application.expect( "Blocks range \(4, 6\)" )
    application.expect( "Blocks range \(5, 6\)" )
    application.expect( "Blocks range \(6, 6\)" )
    application.expect( "Accounts \[\(1, 'account_5', 1\)\]" )
    application.expect( "Blocks range \(None, None\)" )
    application.kill( 0 )

if __name__ == '__main__':
    test_example( sys.argv[ 1 ] + "/hive_accounts_state_provider.py", sys.argv[2] )
