# Hive Application Framework

Contains the implementation of Hive Application Framework which encompass hive node plugin and Postgres specific tools providing
functionalities required by other projects storing blockchain data in the Postrges database.

# Compilation
## Requirements
1. Tested on Ubuntu 20.04
2. postgresql server dev package: `sudo apt-get install postgresql-dev-12`
3. ssl dev package:               `sudo apt-get install libssl-dev`
4. readline dev package:          `sudo apt-get install libreadline-dev`
5. pqxx dev package:              `sudo apt-get install libpqxx-dev`

## CMake and make
This will build all the targets from the HAF repository and `hived` program from submodule `hive`. You can pass
the same CMake parameters which are used to compile hived project ( for example: -DCLEAR_VOTES=ON -DBUILD_HIVE_TESTNET=OFF -DHIVE_LINT=OFF).

2. `git submodule update --init --recursive`
3. create build directory, for exemple in sources root: `mkdir build`
4. `cd build`
5. `cmake -DCMAKE_BUILD_TYPE=Release ..`
6. `make`

### Choose version of the Postgres to compile with
CMake variable `POSTGRES_INSTALLATION_DIR` is used to point the installation folder
with PostgreSQL binaries, by default it is `/usr/lib/postgresql/12/bin` - place where Postgres v.12
is installed on Ubuntu. An example of choosing different version of Postgres:
1. create build directory, for exemple in sources root: `mkdir build`
2. `cd build`
3. `cmake -DPOSTGRES_INSTALLATION_DIR=/usr/lib/postgresql/10/bin ..`
4. `make`

# Tests
The project uses ctest to start tests, just execute in build directory `make test`

Test are grouped in a tree by names and `.` as a branch separator where 'test' is the root.
For example You can start all unit tests with command `ctest -R test.functional.*` 

# Installation
Postgres plugins has to be copied into postgres `$libdir/plugins directory`

You can check postgres `$libdir` directory with: `pg_config --pkglibdir`

The best option is to execute `make install` from build directory (may required to have root privileges)

Note: whenever you build a new version of the hive_fork_marnager extension, you have to create a new database.
There is no way currently to upgrade the schema installed in your old HAF database.

# Architecture
## Directory structure
   ```
   cmake                         Contains common functions used by cmake build
   common_includes
        include                  Constains library interfaces header files, to share them among the project items
   doc                           Contains documentation
   hive                          Submodule of hive project: https://gitlab.syncad.com/hive/hive
   src                           Contains sources
        sql_serializer           C++ hived plugin which is compiled tohether with hived
        transaction_controllers  library with C++ utilities to controll Postgres transactions 
        hive_fork_manager        Contains SQL extension which implements solution for hive forks 
   tests                         Contains test
        integration              Folder for non-unit tests like functional or system tests
          functional             Contains functional tests
        unit                     Contains unit tests and mocks
            mockups              Contains mocks 
   ```

There is also a `generated` directory inside the build directory. It contains autmatically generated headers which can be included
in the code whith ```#include "gen/header_file_name.hpp"```

## PSQL extension based on sql script
If there is a need to create psql extension ( to use CREATE EXTENSION psql command ) a cmake macro is added:
`ADD_PSQL_EXTENSION` with parameters:
- NAME - name of extension, in current source directory file <name>.control (see https://www.postgresql.org/docs/10/extend-extensions.html#id-1.8.3.18.11 ) 
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
