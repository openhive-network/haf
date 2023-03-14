# HAF Server Requirements
## Environment
1. Tested on Ubuntu 22.04
2. To install all required packages, please use script [scripts/setup_ubuntu.sh](./scripts/setup_ubuntu.sh). This script requires root priviledges (since it updates your system). It allows to install system packages specific to development (see `--dev` switch) like also tools specific to running tests (which must be deployed to operating user HOME): see `--user` switch. Additionally, it creates UNIX accounts specific to `hived` and `haf_admin` roles.

# Manually building HAF
Note: below are the instructions for manually building HAF and deploying it directly on a server, but users who are only planning to operate a HAF server or develop HAF apps, but don't plan to actively develop the base HAF layer itself, may want to skip this section and follow the more simplified procedure further down in this document for building and deploying a HAF-based server running inside a docker container.

CMake and ninja are used to build the project (you will typically need to install ninja on your system). The procedure presented below will build all the targets from the HAF repository and the `hived` program from the submodule `hive`. You can pass
the same CMake parameters which are used to compile the hived project ( for example: -DBUILD_HIVE_TESTNET=OFF -GNinja ).

1. `git submodule update --init --recursive`
2. create build directory, for example in sources root: `mkdir build`
3. `cd build`
4. `cmake -DCMAKE_BUILD_TYPE=Release .. -GNinja`
5. `ninja`

You can also use a [scripts/build.sh](./scripts/build.sh) script which encapsulates above process. All what it needs, are paths to source and binary directories (see --help message for details).

### Choose a version of Postgres to compile with
CMake variable `POSTGRES_INSTALLATION_DIR` is used to point to the installation folder
with PostgreSQL binaries. By default it is `/usr/lib/postgresql/<POSTGRES_VERSION>/bin` - place where Postgres RDBMS
is installed on Ubuntu. An example of choosing a different version of Postgres:
1. create build directory, for example in HAF source's root dir: `mkdir build`
2. `cd build`
3. `cmake -DPOSTGRES_INSTALLATION_DIR=/usr/lib/postgresql/15/bin -GNinja ..`
4. `ninja`

# Setup of a directly-hosted HAF server

## 1. One-step solution
Direct host deployment can be significantly simplified by using a [scripts/setup_haf_instance.sh](./scripts/setup_haf_instance.sh) script, which encapsulates all setup steps described below. See `--help` output for details.

If someone would like to perform all steps manually, paragraphs below will cover required actions.

## 1. Configure PostgreSQL cluster
Compiled PostgreSQL plugins and extensions have to be installed in a postgres cluster. The best method
to do this is to execute the command in the build directory (requires root privilieges):
- `sudo scripts/setup_postgres.sh --host="$POSTGRES_HOST" --port="$POSTGRES_PORT" --haf-admin-account="$HAF_ADMIN_ACCOUNT" --haf-binaries-dir="$HAF_BINARY_DIR" --haf-database-store="$HAF_TABLESPACE_LOCATION"
`

This will copy plugins to the Postgres cluster `$libdir/plugins` directory and extensions to `<postgres_shared_dir>/extension`.
Above script also will create required databse roles on you Postgres cluster.

You can check the `$libdir` with command: `pg_config --pkglibdir`, and the shared dir with `pg_config --sharedir`

### - Authorization
It is required to configure standard database roles being members of two special groups: `hived_group` and `hive_applications_group`.

See builtin roles [deployment](https://gitlab.syncad.com/hive/haf/-/blob/develop/scripts/setup_postgres.sh#L36) for details. To have sysadm permission, it is advised to have dedicated role and avoid using postgres user for it. By default it is a `haf_admin` role which is deployed [here](https://gitlab.syncad.com/hive/haf/-/blob/develop/scripts/setup_postgres.sh#L155).
Above builtin roles uses peer authentication scheme, so to use them also UNIX user should be created. Builtin role permissions are discussed in dockerized setup description which performs standard setup procedure of HAF instance - see: [builtin roles description](https://gitlab.syncad.com/hive/haf#access-permissions-specific-to-internal-postgresql-instance)

The HAF will grant to these roles access to its internal elements in a way which gurantees security for the application data and application's execution flows.

To create a custom roles being used in further steps, you can use example statements:
```
   CREATE ROLE my_hived LOGIN PASSWORD 'hivedpass' INHERIT IN ROLE hived_group;
   CREATE ROLE my_application LOGIN PASSWORD 'applicationpass' INHERIT IN ROLE hive_applications_group;
```
The roles which inherits from `hived_groups` must be used by `sql_serializer` process to login into the database.
Roles which inherit from `hive_application_group` shall be used by the applications.
No app role has access to internal data created by other HAF app roles nor can it
modify data written by 'hived'. 'Hived' roles cannot modify the data of HAF apps.

More about roles in PostgreSQL documentaion: [CREATE ROLE](https://www.postgresql.org/docs/14/sql-createrole.html)

Note: HAF DOES NOT support database schema upgrades (specific to hive table definitions). Whenever you build a new version of the hive_fork_manager extension, you have to create a new HAF database (an error is emitted while trying to install newer extension over existing database having differnt table schema).
Altough HFM upgrade is possible, when only binaries or functional code changed - such updates should be correctly performed over existing database.

## 2. Preparing a PostgreSQL database
A newly create HAF database has to have have the hive_fork_manager extension installed. Without this extension, 'sql_serializer'
won't connect the hived node to the database. Mostly, to install the extension in a database, execute the psql
command: `CREATE EXTENSION hive_fork_manager CASCADE;`, but preferred way is to used scripts dedicated to that: [setup_postgres.sh](scripts/setup_postgres.sh) and [setup_db.sh](scripts/setup_db.sh).

The database should use these parameters:
ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' and LC_CTYPE = 'en_US.UTF-8'
(this is default for american english locale, it's not tested on other locale configurations).

# Overview of automated tests for HAF
## 1. Integrations ```tests/integrations```
Integrations tests are tests that are running on a module of the project or on a system of the project's modules.
The tests do not use mock-ups to run modules/system under tests in isolation from their environment, instead
they are **integrated** with the environment, call real OS API functions, cooperate with real working servers, clients applications or databases.
### a) Functional tests ```tests/integrations/functional```
Functional tests are concentrated on testing functions of one module. They test its interface. The tests call
the functions and check the function results.
The project uses ctest to start functional tests. Tests are grouped in a tree by names and `.` as a branch separator where 'test' is the root.
For example, to start all the functional tests: `ctest -R test.functional.*`
### b) Replay tests ```tests/integrations/replay```
The test validates if a module or a system under test works correctly during and after replaying the blockchain from a block_log file.
The tests are written with python, and pytest is used as the test framework.
### c) System tests ```tests/integrations/system```
The tests check interactions between the project's modules.
The tests are written with python, and pytest is used as the test framework.
## 2. Unit ```tests/unit```
Unit tests are used to test parts of modules in isolation from their surrounding environment. This means **all** functions called by the unit under test, which are not part of the unit itself, are **mocked**, and their results are fully controlled by the test framework.

# Directory structure
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
To simplify adding new modules to the project, the build system introduces macros which defines few types of project items.

### 1. Static C++ library
To setup compiler and linker setting to generate static library use macro:

`ADD_STATIC_LIB` with parameter
- target_name - name of the static lib target

The macro adds all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` )

### 2. Run-time loaded C++ library
To setup compiler and linker setting to generate dynamicaly loaded library which will be opened
during program run-time with dlopen, use macro:

`ADD_RUNTIME_LOADED_LIB` with parameter
- target_name - name of the library target

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` )

### 3. Load-time loaded C++ library
To setup compiler and linker setting to generate dynamicaly loaded library which will be loaded
by the loader during startin a program please use macro:

`ADD_LOADTIME_LOADED_LIB` with parameter
- target_name - name of the library target

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` )

### 4. GTest unit test target
To add unit test based on gtest and gmoc frameworks, use macro:

`ADD_UNIT_TESTS` wit parameter
- module_name - name of test module

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` ).
The test `test.unit.<module_name>` is added to ctest.

### 5. PSQL extension based on sql script
If there is a need to create psql extension ( to use CREATE EXTENSION psql command ) a cmake macro is added to cmake:
`ADD_PSQL_EXTENSION` with parameters:
- NAME - name of extension, in current source directory file <name>.control (see https://www.postgresql.org/docs/14/extend-extensions.html#id-1.8.3.18.11 )
- SOURCES - list of sql scripts, the order of the files is important since they are compiled into one sql script

The macro creates a new target extension.<name_of_extension>. The command 'ninja extension.<name_of_extension>' will create
an psql extension in `${CMAKE_BINARY_DIR}/extensions/<name>`.
To install the extension please execute 'sudo ninja install extension.hive_fork_manager'. `sudo` is needed, since installation process puts extension files into PostgreSQL installation directories, being owned by root user.

Warning: 'ninja install' will install all already built project items in the build dir. To install only one of them please build it in a separate build directory, making only the desired target.

# Building and deploying HAF inside a docker container

Unless you are developing HAF itself, you will probably find it easiest to use docker containers to deploy and manage your HAF server.

There are currently two docker files available for deploying HAF:

1. In the "standard" `instance` configuration, both the hived node that collects data from the blockchain and the postgres database server itself are located inside the docker container, but the HAF database data itself is stored outside the docker container on the host, with a docker binding used to map this external location to an internal filesystem location known to the database server. This keeps configuration keeps the docker container itself relatively lightweight, since all the state data is persistently stored on the host system itself. This standard configuration is the one that should be used by API nodes and other production systems. Note: dince the standard configuration doesn't come with a pre-filled database, one of several methods must be used to fill it with already-produced blockchain blocks. There are three available options for filling it: 1) the fastest method is to download and import a HAF database dump from an existing HAF server, 2) the second fastest method is to point the hived process inside the container to a datadir on the host system with downloaded block_log and start hived with the replay option, and 3) the slowest (but least trusting) method is to let the hived process sync from all the blockchain blocks directly from the p2p network.

2. In the "sandbox" `data` configuration, the HAF docker container holds not only the hived process and the database process, it also directly stores the database data itself. In other words, a sandbox container is monolithic and contains all portions of the HAF server. Typically a sandbox container will contain a "filled" version of the HAF database with a fixed number of blocks of data already processed from the blockchain data into HAF table form. The sandbox configuration was designed primarily for Hive app developers who want to quickly deploy a simple HAF server containing some real data so that they can experiment with what can be done with HAF. Currently, the sandbox container for HAF is filled from a block_log file with the first 5 million blockchain blocks.

## Ad 1. Building an `instance` image.

### Building a HAF docker image from a local git repository

To build an `instance` docker image from a local git repo of haf, run the `build_instance.sh` script with a commandline similar to the example below:

```
../haf/scripts/ci-helpers/build_instance.sh local ../haf registry.gitlab.syncad.com/hive/haf/

```

where:
`local` is a suffix to the image tag that will be created for the docker image being built
`../haf` points to the source directory from which to build the docker image
`registry.gitlab.syncad.com/hive/haf/` specifies a docker registry where the built image can potentially be pushed (actualling pushing the image to the registry requires additional steps).

The above command will result in creation of a local docker image: `registry.gitlab.syncad.com/hive/haf/instance:instance-local`

### Building a HAF docker image from a specific git commit hash

A HAF `instance` image can also be built from a specific git commit hash in the HAF repo using the `build_instance4commit.sh` script below:

```
build_instance4commit.sh fdebe397498f814920e959d5d11863d8fe51be22 registry.gitlab.syncad.com/hive/haf/

```
This will create an image called: `registry.gitlab.syncad.com/hive/haf/instance:instance-fdebe397498f814920e959d5d11863d8fe51be22`

## Ad 2. Building a sandboxed `data` image.

If you want to experiment with a sandboxed HAF docker image, then mostly likely you can just use of the prebuilt `data` images stored at https://gitlab.syncad.com/hive/haf/container_registry/

But if do want to build your own image instead, you can use one of the two scripts below:
- `build_data.sh` which builds the image from a local HAF source directory.
- `build_data4commit.sh` which checks out a specific commit hash and builds the image from that commit.

The examples below assume the following directory structure:

```
+--- /home/haf-tester
|
+----/home/haf-tester/haf     # Already checked out haf sources
|
+----/home/haf-tester/workdir # A working directory where the commands described below are executed

```

### Building a HAF `data` image from a source directory

```
../haf/scripts/ci-helpers/build_data.sh local ../haf registry.gitlab.syncad.com/hive/haf/
```
where:
`local` is a suffix to the tag for the docker image
`../haf` points to the source directory to build the docker image from
`registry.gitlab.syncad.com/hive/haf/` specifies a docker registry where the built image can be potentially pushed (push requires additional steps)

The command above will create a local docker image called `registry.gitlab.syncad.com/hive/haf/data:data-local`.

### Building a HAF `data` image from a specified commit

```
../haf/scripts/ci-helpers/build_data4commit.sh fdebe397498f814920e959d5d11863d8fe51be22 registry.gitlab.syncad.com/hive/haf/

```

The command above will create a local docker image called `registry.gitlab.syncad.com/hive/haf/data:data-fdebe397498f814920e959d5d11863d8fe51be22`

## Starting a HAF docker `instance` container
Before you start your HAF instance, you will need to configurate a hived datadir on your host system. For full details on how to do this, you can refer to the docs in the `hive` repo.

Inside your hived datadir, you will need to create a `config.ini` file. Note that the command-line launch of hived forces the sql_serializer plugin to be enabled (HAF depends on it), but you may want to set some of the other options that control how the sql_serializer operates in your config file.


You will probably also want to create a `blockchain` subdirectory with a valid block_log file to reduce the time that would otherwise be required to sync the entire blockchain history from the p2p network.

And finally, you will need to specify a `haf_db_store` directory on your host that the docker container will map the HAF database to. Since this data is stored on the docker container host, it will persist even when the HAF docker container is stopped and restarted.

With these preliminaries out of the way, you can start your `instance` container using a command like the one below:

```
../haf/scripts/run_hived_img.sh registry.gitlab.syncad.com/hive/haf/instance:instance-local --data-dir=/storage1/mainnet-5M-haf --name=haf-instance-5M --replay --stop-replay-at-block=5000000
```

This example works as follows:
- `registry.gitlab.syncad.com/hive/haf/instance:instance-local` points to the HAF image you built in previous steps
- `--data-dir=/storage1/mainnet-5M-haf` option enforces proper volume mapping from your host machine to the docker container you are starting and points to a data directory where the hived node shall put its data.
- `--name=haf-instance-5M`- names your docker container for docker commands.
- other options `--replay --stop-replay-at-block=5000000` are passed directly to hived command line

The container starts in detached mode (similar to a service), so you can see no output directly on your console.

To inspect what the above instance does, you would type `docker logs haf-instance-5M`.
To stop the instance, you would type `docker container stop haf-instance-5M`.

## Accessing already started HAF instance service(s)

  Hived like every regular node, operates on several ports:
  - specific to P2P configuration, by default set to value 2001 inside docker
  - specific to HTTP communication (to support JSON web services supported by Hived instance), by default set to value 8090 inside docker
  - specific to WS communication (i.e. useful for cli_wallet interactions), by default also set to  8090 inside docker.

  Additionally, HAF docker image contains internal PostgreSQL service which is used to hold HAF data. It operates also on standard PostgreSQL port: 5432

  All above ports can be mapped to host specific values by passing dedicated options to docker run command. Refer to docker documentation for details.

  ## Access permissions specific to internal PostgreSQL instance

1.  Roles/Unix account predefined in Docker instance:
    HAF Docker image creates following unix accounts/database roles:
    - haf_admin - unix account (also able to perform sudo). It also contains a database role (called the same) which has configured SUPERUSER permissions. This role shall be used only in exceptional cases, when some administration steps really requiring SUPERUSER permission shall be performed
    - hived - unix account and also database role, which is used to spawn internal hived process. This unix account has limited rights (can't do sudo), but database role has specific rights needed to perform data write to haf_block_log database. Such role is dedicated only to hived usage and shall be not used in other cases.
    - haf_app_admin - this account is only specific to PostgreSQL database role. It has granted limited rights, which are sufficient to regular HAF application actions like creation of other application specific roles, private database scheme like also tables, views and functions defined in this scheme. Given role has declined write access to the `hive` schema (mostly internal HAF data).

1. Accessing internal PostgreSQL held by dockerized HAF instance:
  By default internal PostgreSQL instance allows trusted connections performed by `haf_app_admin` account incoming from network class: `172.0.0.0/8` (this is default IP address range specific to docker bridge network). To connect your application to HAF instance (assuming its container has address: `172.17.0.2`) , you should connect to: `postgresql://haf_app_admin@172.17.0.2/haf_block_log`.<br/><br/>
To override default authorization rules (defined in PostgreSQL pg_hba.conf file), `PG_ACCESS` environment variable can used (it can be overrided by passing `docker run -e PG_ACCESS=value <other-args> <docker-image>` parameter). As its value, whole pg_hba.conf entry should be defined (reflecting PostgreSQL configuration rules), i.e.:<br/>`PG_ACCESS="host    haf_block_log    haf_app_admin  0.0.0.0/0    trust"`<br/>
what can override default rules and allow any netork to access docker internal PostgreSQL service using haf_app_admin account.
There is a way to specify multiple entries - they must be separated by newline character, i.e.: <br/>`PG_ACCESS="host    haf_block_log    haf_app_admin  0.0.0.0/0    trust\n host    haf_block_log    haf_admin  0.0.0.0/0    trust"`

    To perform SQL administration access to the database, most prefered way is to connect directly into docker container using bash, and by operating on haf_admin account (default one after access it) using psql tool any action specific to PostgreSQL instance can be performed. Below is specified example command line which could be used for this operation:
    ```
    docker container exec -it haf-instance-5M /bin/bash
    ```

    where:
    `haf-instance-5M` is a name of previously started docker container
    `/bin/bash` is a command to be executed after attaching container

# HAF Versioning
HAF Postgres extensions are versioned - the extension control file contains `default_version` configuration entry. The build system fills the entry with the repository git sha. The corresponding SQL script file is also named with the same version, as is required by postgres.

# Pghero monitoring

The database `haf_block_log` is ready for monitoring with
[pghero](https://github.com/ankane/pghero/). It is achieved this way:
1. The extension
   [pg_stat_statements](https://www.postgresql.org/docs/12/pgstatstatements.html)
   is enabled on postgresql server by setting `shared_preload_libraries =
   'pg_stat_statements'` in `postgresql.conf`.
2. There's the login role `pghero` added to postgresql's common role
   `pg_monitor`. A required entry enabling login by this role to any
   database exists in `pg_hba.conf` file.
3. The docker entrypoint script installs a set of functions and views
   needed by pghero into schema `pghero` in database `haf_block_log`,
   when it creates postgresql cluster.

When container `haf-instance-5M` is running, you can run pghero web ui
this way:
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
Open page http://localhost:8080 in your browser. Replace
`haf-instance-5M`, in above command, with your name of running HAF
container. Replace `haf_block_log` in above command with another
database, when you want to monitor it. You can install pghero into any
database this way (replace `<your_database>` with your database name):
```bash
docker exec -u root haf-instance-5M ./haf/scripts/setup_pghero.sh --database=<your_database>
```
Another way:
```bash
docker exec haf-instance-5M sudo -n ./haf/scripts/setup_pghero.sh --database=<your_database>
```
Note, that pghero stuff can be installed by postgresql role with
superuser privileges, because pghero needs creating extension
`pg_stat_statements` in database.

To stop pghero web ui and remove its container run:
```bash
docker container rm -f -v pghero 2>/dev/null || true
```

To remove pghero stuff from database just remove schema `pghero` and
drop extension `pg_stat_statements`, for instance:
```bash
docker exec haf-instance-5M psql -d <your_database> \
  -c "drop schema if exists pghero cascade; drop extension if exists pg_stat_statements;"
```

# Using pg_dump/pg_restore to backup/restore a HAF database
When setting up a new HAF server for production or testing purposes, you may want to load data from an existing HAF database using `pg_dump` and `pg_restore` commands, instead of filling it from scratch using hived with a replay of the blockchain data in a block_log.

One problem that arises is that pg_dump doesn't dump tables which are part of a postgres extension, and some tables in HAF are associated with the hive_fork_manager extension. So to use pg_dump to dump a HAF database, you must first temporarily disassociate these tables from the extension, then reassociate them after completing the dump of the database.

Tables can be temporarily disassociated from an extension using the command:
`ALTER EXTENSION <extension name> DROP TABLE <tabel name>;`.

*It is important to note that this command does not drop the tables from the database itself: despite the use of the term "drop" in this command, the tables themselves continue to exist and contain the same data. They are simply no longer associated with the extension, so pg_dump can now dump them to the dump file.*

After the database has been dumped, the tables can be reassociated with an extension using the command:
`ALTER EXTENSION <extension name> ADD TABLE <tabel name>;`
This reassociation needs to be done to the original database that was dumped, and also to any database that is restored from the dumpfile using `pg_rstore`.

Hive_fork_manager has prepared scripts which disassociate and reassociate its tables: [./src/hive_fork_manager/tools/pg_dump](./src/hive_fork_manager/tools/pg_dump/readme.md).
