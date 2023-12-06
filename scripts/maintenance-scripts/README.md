# Running tests locally
It is possible to run some tests locally by maintenance scripts:
docker run <image name> --execute-maintenance-script=<script name> [ arguments ]


For example:

docker run -ePYTEST_NUMBER_OF_PROCESSES="0" -ePG_ACCESS="host all all 127.0.0.1/32 trust" registry.gitlab.syncad.com/hive/haf/testnet-base_instance:4a2d57c --execute-maintenance-script=/home/haf_admin/haf/scripts/maintenance-scripts/run_haf_system_tests.sh test_operations_after_switching_fork.py

docker run -ePG_ACCESS="host all all 127.0.0.1/32 trust" registry.gitlab.syncad.com/hive/haf/base_instance:4a2d57c --execute-maintenance-script=/home/haf_admin/haf/scripts/maintenance-scripts/run_hfm_functional_tests.sh

PG_ACCESS - is environmant variable required in functional and system tests, arguments are optional and currently work only in system tests.
