# Hive Fork Manager system tests
The tests start scripts and nodes which checks hive_fork_manager extension functionalities.
Nodes start from pre generated blockchain. To allow nodes
to startup from generated before blockchain, libfaketime is used to change time for single process. To run all tests execute
command `tox`. To run only once specific test, run for example `tox test_undo_operations.py`.

# Requirements
The tests require to have configured locally (means on local host) postgres server with the current system user as postgres SUPERUSER with CREATEDB option
and authentication method peer(setting inside `pg_hba.conf`).

Python is required to be available on system. Tests are working correctly on python3.6 and python 3.8 (thought it shouldn't be problem to use different python version, just update tox.ini or set appripiate TOXENV environment variable, i.e. by `export TOXENV=py39`)

libfaketime is also required, it can by installed from ubuntu package repository (`sudo apt-get install libfaketime`) or by compiling from source https://github.com/wolfcw/libfaketime.git and setting LIBFAKETIME_PATH variable to shared object file.

During some tests its required to enable track_functions in postgres, simly type "ALTER SYSTEM SET track_functions TO pl;"
and "SELECT pg_reload_conf();".

If test envinronment is not prepared by cmake, following environment variables should be set before running tests:
PYTHONPATH - pointing test_tools and local_tools
HIVE_BUILD_ROOT_PATH  - pointing to folder where were fuild following executables: hived, cli_wallet, get_dev_key.
LIBFAKETIME_PATH - optionally pointing to libfaketime shared object, not required if libfaketime is installed in location '/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1'.
