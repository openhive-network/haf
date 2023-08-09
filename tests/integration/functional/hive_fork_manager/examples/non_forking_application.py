#!/usr/bin/env python3
import pexpect
import sys

def test_example( example_path, db_name, pg_port ):
    print( "Test example {}".format( example_path ) )
    application = pexpect.spawn( example_path, [db_name, pg_port] )
    application.logfile = sys.stdout.buffer
    application.expect( "Blocks range \(1, 6\)" )
    application.expect( "Blocks range \(2, 6\)" )
    application.expect( "Blocks range \(3, 6\)" )
    application.expect( "Blocks range \(4, 6\)" )
    application.expect( "Blocks range \(5, 6\)" )
    application.expect( "Blocks range \(6, 6\)\r\n" )
    # no more irreversible blocks, (None, None) must be returned
    last_expected_line =  application.readline()
    assert last_expected_line == b'Blocks range (None, None)\r\n', f"Unexpected message {last_expected_line}"
    application.kill( 0 )

if __name__ == '__main__':
    test_example( sys.argv[ 1 ] + "/hive_non_fork_app.py", sys.argv[2], sys.argv[3] )
