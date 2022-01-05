# Hive Application Framework

Contains the implementation of Hive Application Framework which encompass hive node plugin and Postgres specific tools providing
functionalities required by other projects storing blockchain data in the Postrges database.
The HAF works between the HIVE network and the applications

![alt text](./doc/c2_haf.png)

The HAF contains a few components visible at the picture above:
* **HIVED - hive node**
  Regular HIVE node which syncs blocks with the HIVE network or replays them from block.log file.
* **SQL_SERIALIZER**
  A hived's plugin (the hive node plugin) which during syncing a new block pushes its data to SQL database. Moreover, the plugin informs the database about the occurrence of micro-fork and changing a block status from reversible to irreversible.
  A detailed documentation for sql_serializer is here: [src/sql_serializer/README.md](./src/sql_serializer/README.md)
* **PostgreSQL database**
  The database contains the blockchain blocks data in form of filled SQL tables, and the applications tables. The system utilizes Postgres authentication and authorization mechanisms.
* **HIVE FORK MANAGER**
  The PostgreSQL extension provides the HAF's API - a set of SQL functions that are used by the application to get blocks data. The extension controls the process by which applications consume blocks and ensures that applications cannot corrupt each other. The HIVE FORK MANAGER is responsible for rewind the applications tables changes in case of micro-fork occurrence. The extension defines the format of blocks data saved in the database. The SQL_SERIALIZER dumps blocks to the tables defined by HIVE FORK MANAGER.
  A detailed documentation for hive_fork_manager is here: [src/hive_fork_manager/Readme.md](./src/hive_fork_manager/Readme.md)

# Requirements
## Environment
1. Tested on Ubuntu 20.04
2. postgresql server dev package: `sudo apt-get install postgresql-dev-12`
3. ssl dev package:               `sudo apt-get install libssl-dev`
4. readline dev package:          `sudo apt-get install libreadline-dev`
5. pqxx dev package:              `sudo apt-get install libpqxx-dev`

## PostgreSQL cluster
The project is intended to run on postgres version 12 or higher, however it is possible to use it
on older verisions but without any guaranteens.

# Build
CMake and make is used to build the project. Procedure presented below will build all the targets from the HAF repository and `hived` program from submodule `hive`. You can pass
the same CMake parameters which are used to compile hived project ( for example: -DCLEAR_VOTES=ON -DBUILD_HIVE_TESTNET=OFF -DHIVE_LINT=OFF).

1. `git submodule update --init --recursive`
2. create build directory, for example in sources root: `mkdir build`
3. `cd build`
4. `cmake -DCMAKE_BUILD_TYPE=Release ..`
5. `make`

### Choose version of the Postgres to compile with
CMake variable `POSTGRES_INSTALLATION_DIR` is used to point the installation folder
with PostgreSQL binaries, by default it is `/usr/lib/postgresql/12/bin` - place where Postgres v.12
is installed on Ubuntu. An example of choosing different version of Postgres:
1. create build directory, for exemple in sources root: `mkdir build`
2. `cd build`
3. `cmake -DPOSTGRES_INSTALLATION_DIR=/usr/lib/postgresql/10/bin ..`
4. `make`

# Installation
## 1. Configure PostgreSQL cluster
Compiled PostgreSQL plugins and extensions have to be installed in the cluster. The best method
to do this is execute in the build directory (may require root privilieges):
- `make install`

This will copy plugins to the Postgres cluster `$libdir/plugins` directory and exstensions to
`<postgres_shared_dir>/extension`.

You can check the `$libdir` with command: `pg_config --pkglibdir`, and the shared dir with `pg_config --sharedir`

### - Authorization
It is required to configure two based roles:
```
CREATE ROLE hived_group WITH NOLOGIN;
CREATE ROLE hive_applications_group WITH NOLOGIN;
```
The HAF will grant to them access to its internal elements in a way which gurantees security for the application data
and applications execution flows.
The maintainer of the PostgreSQL cluster server needs to create roles ( users ) which inherits from one of these groups for example:
```
   CREATE ROLE hived LOGIN PASSWORD 'hivedpass' INHERIT IN ROLE hived_group;
   CREATE ROLE application LOGIN PASSWORD 'applicationpass' INHERIT IN ROLE hive_applications_group;
```
The roles which inherits from `hived_groups` must be used by `sql_serializer` process to login into the database
, roles which inherit from `hive_application_group` shall be used by the applications.
Each application role does not have access to internal data created by other application roles and cannot
modify data modified by the 'hived'. 'Hived' roles cannot modify the applications data.

More about roles in PostgreSQL documentaion: [CREATE ROLE](https://www.postgresql.org/docs/10/sql-createrole.html) 

Note: whenever you build a new version of the extensions, you have to create a new database.
There is no way currently to upgrade the schema installed in your old HAF database.

## 2. Preparing a PostgreSQL database
The newly create database have to have created hive_fork_manager extension. Without this 'sql_serializer'
won't connect the hived node with database. To start using the extension in a database, execute psql
command: `CREATE EXTENSION hive_fork_manager CASCADE;`. The CASCADE phrase is needed, to automatically install extensions the hive_fork_manager depends on.

The database should use parameters
ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' and LC_CTYPE = 'en_US.UTF-8' (this is default for american english locale,
it's not tested on other locale configurations).

# Tests
## 1. Integrations ```tests/integrations```
Integrations tests are tests that are running on a module of the project or on a system of the projects modules.
The tests do not use mock-ups to run modules/system under tests in isolation from their environment, instead
they are **integrated** with the environment, call real OS API functions, cooperate with real working servers, clients applications or databases.
### a) Functional tests ```tests/integrations/functional```
Functional tests are concentrated on tests functions of one module, they test its interface. The tests call
the functions and check results. 
The project uses ctest to start functional tests. Tests are grouped in a tree by names and `.` as a branch separator where 'test' is the root.
For example You can start all the functional tests with command `ctest -R test.functional.*`
### b) Replay tests ```tests/integrations/replay```
The test validates if a module or a system under test works correctly during and after replaying the blockchain from block_log file.
The tests are written with python and pytest is used as the test framework. 
### c) System tests ```tests/integrations/system```
The tests check interactions between the projects modules.
The tests are written with python and pytest is used as the test framework.
## 2. Unit ```tests/unit```
Unit tests are used to test parts of modules in isolation from the environment, it means **all** the functions
called by the unit under test, which are not part of the unit, are mocked and their results are fully controlled by the test framework.

# Directory structure
   ```
   cmake                         Contains common functions used by cmake build
   common_includes
        include                  Constains library interfaces header files, to share them among the project items
   doc                           Contains documentation
   hive                          Submodule of hive project: https://gitlab.syncad.com/hive/hive
   src                           Contains sources
        applications             Contains utilities which help to develop HIVE applications based on HAF
        hive_fork_manager        Contains SQL extension which implements solution for hive forks
        sql_serializer           C++ hived plugin which is compiled tohether with hived
        transaction_controllers  library with C++ utilities to controll Postgres transactions 
   tests                         Contains test
        integration              Folder for non-unit tests like functional or system tests
          functional             Contains functional tests
          replay                 Tests which checks replayin HAF from block_log file
          system                 Tests which chechc interactions between hived internals, sql_serializer, hive_fork_mnager and an application
        unit                     Contains unit tests and mocks
            mockups              Contains mocks 
   ```

There is also a `generated` directory inside the build directory. It contains autmatically generated headers which can be included
in the code whith ```#include "gen/header_file_name.hpp"```

# Predefined cmake targetes
To simplify adding new modules to the project the build system introduces macros which defines few types of project items. 

## 1. Static C++ library
To setup compiler and linker setting to generate static library use macro:

`ADD_STATIC_LIB` with parameter
- target_name - name of the static lib target

The macro adds all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` ) 

## 2. Run-time loaded C++ library
To setup compiler and linker setting to generate dynamicaly loaded library which will be opened
during program run-time with dlopen please use macro:

`ADD_RUNTIME_LOADED_LIB` with parameter
- target_name - name of the library target

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` )

## 3. Load-time loaded C++ library
To setup compiler and linker setting to generate dynamicaly loaded library which will be loaded
by the loader during startin a program please use macro:

`ADD_LOADTIME_LOADED_LIB` with parameter
- target_name - name of the library target

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` )

## 4. GTest unit test target
To add unit test based on gtest and gmoc frameworks pleas use a macro

`ADD_UNIT_TESTS` wit parameter
- module_name - name of test module

The macro adds to compilation all *.cpp files from the directory in which the `CMakeLists.txt` file is placed ( `${CMAKE_CURRENT_SOURCE_DIR}` ).
The test `test.unit.<module_name>` is added to ctest.

## 5. PSQL extension based on sql script
If there is a need to create psql extension ( to use CREATE EXTENSION psql command ) a cmake macro is added to cmake:
`ADD_PSQL_EXTENSION` with parameters:
- NAME - name of extension, in current source directory file <name>.control (see https://www.postgresql.org/docs/12/extend-extensions.html#id-1.8.3.18.11 ) 
- SOURCES - list of sql scripts, the order of the files is important since they are compiled into one sql script

The macro creates a new target extension.<name_of_extension>. The command 'make extension.<name_of_extension>' will create
an psql extension in `${CMAKE_BINARY_DIR}/extensions/<name>`.
To install the extension please execute 'make install'.

Warning: Make install will install all already builded project items, to install only one of them please build it
in separated build directory with making the only one target, for example: `make extension.hive_fork_manager; make install;` 

### Versioning
Postgres extensions are versioned - extension control file contains `default_version` configuration entry. The build system
fills the entry with the repository git sha.
Also corresponding sql script file is named with the same version, as is required by the postgres.

# Known problems
