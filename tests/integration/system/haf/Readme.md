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

If test envinronment is not prepared by cmake, following environment variables should be set before running tests:
PYTHONPATH - pointing test_tools
HIVE_BUILD_ROOT_PATH  - pointing to folder where were fuild following executables: hived, cli_wallet, get_dev_key.
LIBFAKETIME_PATH - optionally pointing to libfaketime shared object, not required if libfaketime is installed in location '/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1'.

# Types of test

## generate_block_log.py
This section is not required to just run tests.
generate_block_log.py is script allowing to pre generate block_log to be used in above tests. Just run `./generate_block_log.py`. Required are variables:
PYTHONPATH - pointing test_tools
HIVE_BUILD_ROOT_PATH  - pointing to folder where were fuild following executables: hived, cli_wallet, get_dev_key and also truncate_block_log.
Optionally specify desired block_log length, i.e. `./generate_block_log.py --length 126`. Default length is 105. Block log will be saved to file `block_log`.
There is also head block timestamp which is needed when starting nodes with faketime. It will be saved in file `timestamp`. After regeneration
of both files, they will by automatically used when running tests.
