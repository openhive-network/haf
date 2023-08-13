HAF Detailed Deployment Instructions

[TOC]
# Building and deploying HAF inside a docker container

Unless you are developing HAF itself, you will probably find it easiest to use docker containers to deploy and manage your HAF server.

In the standard "instance" configuration, both the hived node that collects data from the blockchain and the postgres database server itself are located inside the docker container. However, the HAF database data itself is stored outside the docker container on the host, with a docker binding used to map this external location to an internal filesystem location known to the database server. 

This reduces the need to modify the internal files of the docker container, since all the state data is persistently stored on the host itself. This standard configuration should be used by API nodes and other production systems.

Since the standard configuration doesn't come with a pre-filled HAF database, one of several methods must be used to fill it with already-produced blockchain blocks. There are three available options for filling it:
- the fastest method is to download and import a HAF database dump from an existing HAF server.
- the second fastest method is to point the hived process inside the container to a datadir on the host system with a downloaded block_log and start hived with the replay option.
- the slowest (but least trusting) method is to let hived sync all the blockchain blocks directly from the p2p network.

## Options for building an instance image

### Building a HAF docker image from a local git repository

To build an instance docker image from a HAF repo, perform the steps below:

```
git clone --recurse --branch develop https://gitlab.syncad.com/hive/haf.git
./haf/scripts/ci-helpers/build_instance.sh local ./haf registry.gitlab.syncad.com/hive/haf/
```

where:
`local` is a suffix to the image tag that will be created for the docker image being built
`./haf` points to the source directory from which to build the docker image
`registry.gitlab.syncad.com/hive/haf/` specifies a docker registry where the built image can potentially be pushed (actually pushing the image to the registry requires additional steps).

The above command will result in creation of a local docker image: `registry.gitlab.syncad.com/hive/haf/instance:instance-local`

### Building a HAF docker image from a specific git commit hash

A HAF instance image can also be built from a specific git commit hash in the HAF repo using the `build_instance4commit.sh` script below:

```
build_instance4commit.sh fdebe397498f814920e959d5d11863d8fe51be22 registry.gitlab.syncad.com/hive/haf/

```
This will create an image called: `registry.gitlab.syncad.com/hive/haf/instance:instance-fdebe397498f814920e959d5d11863d8fe51be22`

The examples below assume the following directory structure:

```
+--- /home/haf-tester
|
+----/home/haf-tester/haf     # Already checked out HAF sources
|
+----/home/haf-tester/workdir # A working directory where the commands described below are executed
```

## Starting a HAF server container
Before you start your HAF server, you will typically want to configure a hived datadir on your host system to speed up filling your hive database. For full details on how to do this, you can refer to the docs in the `hive` repo, but below is a short summary of steps required to speed up setup.

Create a hived datadir on your host. Inside your hived datadir, create a `config.ini` file. Note that the command-line launch of hived forces the sql_serializer plugin to be enabled (HAF depends on it), so you may want to set some of the other options that control how the sql_serializer operates inside your config file.

Next create a `blockchain` subdirectory inside the datadir with a valid block_log and block_log.artifacts file to reduce the time that would otherwise be required to sync the entire blockchain history from the p2p network.

With these preliminaries out of the way, you can start your instance container using a command like the one below:

```
./haf/scripts/run_hived_img.sh registry.gitlab.syncad.com/hive/haf/instance:instance-local --data-dir=/storage1/mainnet-5M-haf --name=haf-instance-5M --replay --stop-replay-at-block=5000000
```

This example works as follows:
- `registry.gitlab.syncad.com/hive/haf/instance:instance-local` points to the HAF image you built in previous steps.
- `--data-dir=/storage1/mainnet-5M-haf` option enforces proper volume mapping from your host machine to the docker container you are starting and points to a data directory where the hived node shall put its data.
- `--name=haf-instance-5M`- names your docker container for docker commands.
- other options `--replay --stop-replay-at-block=5000000` are passed directly to the hived command line

Note: since no directory was specified for storing the HAF database on the host, it will be stored in a subdirectory of the hived datadir called haf_db_store (i.e. /storage1/mainnet-5M-haf/haf_db_store).

The container starts in attached mode, so you can see output directly on your console. You can use the stardard docker shortcut Ctrl+p, Ctrl+q to detach.

To inspect what the above instance does, type `docker logs haf-instance-5M`.
To stop the instance, type `docker container stop haf-instance-5M`.

All the persistent data required by a HAF instance after restart is stored on the host inside the mapped data-directory, so the container can easily be removed, although it must be shutdown cleanly to correctly flush hived and postgreSQL data.

## Mapping ports on an already running HAF server

Hived operates on several ports:
  - P2P port for hived (defaults to 2001 inside container)
  - HTTP port for hived to support JSON-RPC calls (defaults to 8090 inside container)
  - WebSocket port (useful for cli_wallet support) (defaults to 8090 inside docker)

Additionally, the HAF docker image contains a postgreSQL cluster which manages HAF data. It operates on the standard postgreSQL port (5432).

All the above ports can be mapped to host-specific values by passing dedicated options to the docker run command. Refer to docker documentation for details.

## Managing a HAF database

### Pre-defined roles and unix accounts in the image

The HAF docker image creates the following database roles and unix accounts:
  - `haf_app_admin`:  This role should normally be used to add, remove, and maintain HAF apps on the server. This role has no associated unix account (normally it is authenticated via privileged network connections instead). It has sufficient rights to perform regular HAF app maintenance tasks such as creation of app-specific roles and manage app-specific database schemas (e.g. tables, views, and functions). This role does not have write access to the `hive` schema (which contains HAF data shared by all apps).
  - `haf_admin`: This role should only be used in exceptional cases when some administration steps requiring SUPERUSER permission need to be performed. Unlike the haf_app_admin role, this role can also change data in the core hive schema that contains blockchain data sent by hived. A unix account with the same name is also created that can be used for authentication.
  - `hived`: This role is used by the sql_serializer plugin of hived to write to the haf_block_log database. It should not be used for other purposes. There is an associated unix account which is used to spawn hived. This unix account does not have sudo privilege.

### Managing HAF apps in the postgreSQL cluster

By default, the postgreSQL cluster allows clients from the default docker bridge network (i.e. `172.0.0.0/8`) to be automatically authenticated as the `haf_app_admin` role.
  
To connect your database administration tool to the HAF database (assuming the container has address: `172.17.0.2`) and administer it, you should connect to `postgreSQL://haf_app_admin@172.17.0.2/haf_block_log`.

There are two ways to customize the host-based authentication rules defined in the postgreSQL pg_hba.conf file:
  - Create a `haf_postgreSQL_conf.d` subdirectory inside your mapped data-dir and put there `custom_postgres.conf` and `custom_pg_hba.conf` files containing your settings. You can use example files located in [doc/haf_postgreSQL_conf.d](./doc/haf_postgreSQL_conf.d)
  - Set the `PG_ACCESS` environment variable (value set with the same format as a pg_hba.conf entry). For example: `docker run -e PG_ACCESS=PG_ACCESS="host    haf_block_log    haf_app_admin  0.0.0.0/0    trust" <other-args> <docker-image>`

The example above will override the default authentication rule and allow any network connection to access the postgreSQL cluster using the haf_app_admin role.

There is a way to specify multiple entries. They must be separated by a newline character, i.e.:
 <br/>`PG_ACCESS="host    haf_block_log    haf_app_admin  0.0.0.0/0    trust\n host    haf_block_log    haf_admin  0.0.0.0/0    trust"`

### Superuser access to the postgreSQL cluster

The recommended way to get superuser access to the database is to login to the docker container using bash. This will log you into the haf_admin user account. Next you can use psql to administer the database. For example:
    ```
    docker container exec -it haf-instance-5M /bin/bash
    psql -d haf_block_log
    ```

    where:
    `haf-instance-5M` is a name of a previously started docker container
    `/bin/bash` is a command to be executed after attaching to the container

# Pghero monitoring

The database `haf_block_log` is ready for monitoring with [pghero](https://github.com/ankane/pghero/). To enable pghero monitoring:
1. The extension [pg_stat_statements](https://www.postgreSQL.org/docs/12/pgstatstatements.html)
   is enabled on the postgreSQL cluster by setting `shared_preload_libraries = 'pg_stat_statements'` in `postgreSQL.conf`.
2. The login role `pghero` is added to postgreSQL's common role `pg_monitor`. A required entry enabling login by this role to any database exists in `pg_hba.conf` file.
3. The docker entrypoint script installs a set of functions and views needed by pghero into the schema `pghero` in the `haf_block_log` database when it creates the postgreSQL cluster.

When the container `haf-instance-5M` is running, you can run the pghero web UI by typing:
```bash
docker container rm -f -v pghero 2>/dev/null || true \
&& docker run \
    --name pghero \
    -d \
    --link haf-instance-5M:db \
    -e DATABASE_URL=postgres://pghero@db:5432/haf_block_log \
    -p 8080:8080 \
    ankane/pghero:v2.7.2
```
Open the url http://localhost:8080 in your browser. Replace `haf-instance-5M` in the above command with the name of your HAF container. 
If you use a different name for your database, replace `haf_block_log` in the above command with your database name.
To install pghero into your database (replace `<your_database>` with your database name):
```bash
docker exec -u root haf-instance-5M ./haf/scripts/setup_pghero.sh --database=<your_database>
```
Or alternatively:
```bash
docker exec haf-instance-5M sudo -n ./haf/scripts/setup_pghero.sh --database=<your_database>
```
Note that pghero should be installed using the postgreSQL role with superuser privileges, because pghero needs to create the extension `pg_stat_statements` in the database.

To stop the pghero web UI and remove its container, run:
```bash
docker container rm -f -v pghero 2>/dev/null || true
```

To remove pghero from a database, just remove the schema `pghero` and drop the extension `pg_stat_statements`.
For example:
```bash
docker exec haf-instance-5M psql -d <your_database> \
  -c "drop schema if exists pghero cascade; drop extension if exists pg_stat_statements;"
```

# Using scripts to perform a full backup
In addition to backing up the HAF database, you also need to backup the state of the hived node.
To perform a full backup of both:
1. Stop the hived server
2. execute ```dump_instance.sh```


To perform a full restore and immediately run the hived server:
1. execute ```load_instance.sh```

All unrecognized options are forwarded to the hived executable.

E.g.:

```scripts/dump_instance.sh --backup-dir=path_to_backup_directory \
--hived-executable-path=path_to_hived \
--hived-data-dir=path_to_hived_datadir \
--haf-db-name=haf_block_log \
--override-existing-backup-dir \
--exit-before-sync

scripts/load_instance.sh --backup-dir=path_to_backup_directory
--hived-executable-path=path_to_hived \
--hived-data-dir=path_to_hived_datadir \
--haf-db-name=haf_block_log \
--exit-before-sync --stop-replay-at-block=5000000
```

# HAF Versioning
HAF Postgres extensions are versioned - the extension control file contains a `default_version` configuration entry. The build system fills this entry with the repository git SHA hash. The corresponding SQL script file is also named with the same version (required by postgres).

# Manually building HAF
Note: the instructions below are for manually building HAF and deploying it directly on a server. Users who are only planning to operate a HAF server or develop HAF apps, but don't plan to actively develop HAF itself, only need to follow the simplified procedure at the top of this document to build and deploy a HAF-based server running inside a docker container.

### Requirements for manually building and directly running a HAF server
1. Tested on Ubuntu 22.04.
2. To install all required packages, use the script [scripts/setup_ubuntu.sh](./scripts/setup_ubuntu.sh). This script requires root privileges because it updates your system. It installs the packages and tools required for development (see `--dev` switch) and for running tests. These tools should be installed relative to the home directory of the user: see `--user` switch. This script also creates UNIX accounts specific to the `hived` and `haf_admin` roles. 

## Steps to manually compile HAF

CMake and ninja are used to build the project. The procedure presented below will build all the targets from the HAF repository and the `hived` program from the submodule `hive`. You can pass the same CMake parameters which are used to compile the hived project (for example: -DBUILD_HIVE_TESTNET=OFF -GNinja ).

```bash
git submodule update --init --recursive
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release .. -GNinja
ninja
```

You can also use the [scripts/build.sh](./scripts/build.sh) script which encapsulates the steps above. It only needs paths to the source and binary directories (see --help message for details).

# Setup of a directly-hosted HAF server

## One-step solution
Direct host deployment can be significantly simplified by using the [scripts/setup_haf_instance.sh](./scripts/setup_haf_instance.sh) script which encapsulates all the setup steps described below. See `--help` output for details.

## Manual setup
While using the above script is recommended, below is a description of how to perform a manual setup:

### Configure a postgreSQL cluster
Compiled postgreSQL plugins and extensions have to be installed in a postgres cluster. The best method to do this is to execute the command in the build directory (requires root privilieges):
```
sudo scripts/setup_postgres.sh --host="$POSTGRES_HOST" --port="$POSTGRES_PORT" --haf-admin-account="$HAF_ADMIN_ACCOUNT" --haf-binaries-dir="$HAF_BINARY_DIR" --haf-database-store="$HAF_TABLESPACE_LOCATION"
```

This will copy plugins to the Postgres cluster `$libdir/plugins` directory and extensions to `<postgres_shared_dir>/extension`.
The postgres setup script will also create HAF-specific database roles for your postgres cluster.

You can check the `$libdir` with command: `pg_config --pkglibdir` and the shared dir with `pg_config --sharedir`

#### Authorization

Several custom roles are defined for secure administration of HAF servers. See builtin roles [deployment](https://gitlab.syncad.com/hive/haf/-/blob/develop/scripts/setup_postgres.sh#L36) for details. 

To have sysadm permission, it is advised to create a dedicated role instead of using the postgres user role. 
By default, the[setup_postgres](https://gitlab.syncad.com/hive/haf/-/blob/develop/scripts/setup_postgres.sh#L155) script will create the haf_admin role for this purpose.
The roles created by the setup script use the peer authentication scheme, so same-named UNIX users should also be created. Builtin role permissions are discussed in the dockerized setup description which performs standard setup procedure of a HAF instance - see: [builtin roles description](https://gitlab.syncad.com/hive/haf#access-permissions-specific-to-internal-postgreSQL-instance)

A HAF database will grant to these roles access to its internal elements in a way which gurantees security for the application data and the application's execution flows.

For example, to create custom roles used in later steps:
```
   CREATE ROLE my_hived LOGIN PASSWORD 'hivedpass' INHERIT IN ROLE hived_group;
   CREATE ROLE my_application LOGIN PASSWORD 'applicationpass' INHERIT IN ROLE hive_applications_group;
```
The roles which inherits from `hived_groups` must be used by the `sql_serializer` process to login into the database.
Roles which inherit from `hive_application_group` will be used by HAF apps.
No app role has access to internal data created by other HAF app roles, nor can it modify data written by 'hived'.
'Hived' roles cannot modify the data of HAF apps.

More details about roles can be found in postgreSQL documentation: [CREATE ROLE](https://www.postgreSQL.org/docs/14/sql-createrole.html)

Note: HAF DOES NOT support database schema upgrades (specific to hive table definitions). Whenever you build a new version of the hive_fork_manager (HFM) extension, you must create a new HAF database. An error will be emitted while trying to install a newer extension over an existing database with a different table schema.

Although an HFM upgrade is possible when only binaries or functional code has changed, such updates should be correctly performed on the existing database.

### Preparing a postgreSQL database
A newly created HAF database has to have the hive_fork_manager extension installed. Without this extension, 'sql_serializer' won't connect hived to the database. You can directly install this extension by executing the psql command: `CREATE EXTENSION hive_fork_manager CASCADE;`, but the preferred way is to use the scripts: [setup_postgres.sh](scripts/setup_postgres.sh) and [setup_db.sh](scripts/setup_db.sh).

The database should use these parameters:
ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' and LC_CTYPE = 'en_US.UTF-8'
(this is default for the american english locale, it has not been tested on other locale configurations).

# Overview of automated tests for HAF
## Integrations ```tests/integrations```
Integrations tests are tests that are running on a module of the project or on a system of the project's modules.
These tests do not use mock-ups to run modules/system under tests in isolation from their environment, instead
they are **integrated** with the environment, call real OS API functions, cooperate with real working servers, clients applications or databases.
### Functional tests ```tests/integrations/functional```
Functional tests are concentrated on testing functions of one module. They test its interface. The tests call
the functions and check the function results.
The project uses ctest to start functional tests. Tests are grouped in a tree by names and `.` as a branch separator where 'test' is the root.
For example, to start all the functional tests: `ctest -R test.functional.*`
### Replay tests ```tests/integrations/replay```
This test validates if a module or a system under test works correctly during and after replaying the blockchain from a block_log file.
These tests are written in python and pytest is used as the test framework.
### System tests ```tests/integrations/system```
These tests check interactions between the project's modules.
The tests are written with python, and pytest is used as the test framework.
## Unit ```tests/unit```
Unit tests are used to test parts of modules in isolation from their surrounding environment. This means **all** functions called by the unit under test, which are not part of the unit itself, are **mocked**, and their results are fully controlled by the test framework.

# HAF repo tree description
   ```
   cmake                         Contains common functions used by cmake build
   common_includes
        include                  Contains library interface header files, to share them among the project items
   doc                           Contains documentation
   hive                          Submodule containing hived project: https://gitlab.syncad.com/hive/hive
   src                           Contains sources
        applications             Contains utilities which help to develop Hive applications based on HAF
        hive_fork_manager        Contains SQL extension which implements solution for hive forks
        sql_serializer           C++ hived plugin which is compiled together with hived
        transaction_controllers  library with C++ utilities to control Postgres transactions
   tests                         Contains tests for HAF
        integration              Folder for non-unit tests like functional or system tests
          functional             Contains functional tests
          replay                 Tests which checks replaying HAF from block_log file
          system                 Tests which check interactions between hived internals, sql_serializer, hive_fork_mnager and an application
        unit                     Contains unit tests and mocks
            mockups              Contains mocks
   ```

There is also a `generated` directory inside the build directory that contains automatically generated headers which can be included in the code with ```#include "gen/header_file_name.hpp"```

# Internal docs for HAF's cmake files
## Predefined cmake targets
To simplify adding new modules to the project, the build system introduces macros which define a few type of project items.

### Static C++ library
To setup compiler and linker setting to generate a static library use this macro:

`ADD_STATIC_LIB` with parameter
- target_name - name of the static lib target

The macro adds all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` )

### Run-time loaded C++ library
To setup compiler and linker settings to generate a dynamicaly loaded library which will be opened
during program run-time with dlopen, use this macro:

`ADD_RUNTIME_LOADED_LIB` with parameter
- target_name - name of the library target

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` )

### Load-time loaded C++ library
To setup compiler and linker settings to generate dynamicaly loaded library which will be loaded
by the loader during program startup, use this macro:

`ADD_LOADTIME_LOADED_LIB` with parameter
- target_name - name of the library target

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` )

### GTest unit test target
To add a unit test based on gtest and gmoc frameworks, use this macro:

`ADD_UNIT_TESTS` with parameter
- module_name - name of test module

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` ).
The test `test.unit.<module_name>` is added to ctest.

### PSQL extension based on sql script
If there is a need to create a psql extension ( to use CREATE EXTENSION psql command ) a cmake macro invocation should be added to the cmake file:
`ADD_PSQL_EXTENSION` with parameters:
- NAME - name of extension. Must match the basename of the <name_of_extension>.control file in the source directory (see https://www.postgreSQL.org/docs/14/extend-extensions.html#id-1.8.3.18.11 ).
- SOURCES - list of sql scripts. The order of the files is important since they are compiled into one sql script.

The macro creates a new target extension.<name_of_extension>. The command `ninja extension.<name_of_extension>` will create a psql extension in `${CMAKE_BINARY_DIR}/extensions/<name_of_extension>`.

To install the extension, run `sudo ninja install extension.<name_of_extension>`. `sudo` is needed since the installation process puts extension files into the postgreSQL installation directories (which are owned by the root user).

Warning: 'ninja install' will install all project items contained in the build dir. To install only one of them, build it in a separate build directory where you only make the desired target.
