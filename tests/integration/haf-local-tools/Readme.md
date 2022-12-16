# tools shared by integration tests: haf system tests and replay tests

## generate_block_log.py
When running system tests we use pregenerated testnet block_log with witnesses (full witnesses are required to simulate fork it network).
There shouldn't really be any need to regenerate block_log (regardless of any possible future hardforks), but in this case this script
can be used.

Just run `./generate_block_log.py`. Required are environment variables:
PYTHONPATH - pointing test_tools
HIVE_BUILD_ROOT_PATH  - pointing to folder where were fuild following executables: hived, cli_wallet, get_dev_key and also truncate_block_log.
Optionally specify desired block_log length, i.e. `./generate_block_log.py --length 126`. Default length is 105. Block log will be saved to file `block_log`.

There is also head block timestamp which is needed when starting nodes with faketime. It will be saved in file `timestamp`. After regeneration
of both files, they will by automatically used when running tests.
