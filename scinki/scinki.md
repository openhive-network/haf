# Display table in Postgress
    raise notice 'zawartosc_old=%',(select json_agg(t) FROM (SELECT * from hive.get_balance_impacting_operations_old(True)) t);

# puszczanie ninja
ninja && sudo ninja install && sudo chown $USER:$USER .ninja_* && ctest -R \(keyauth\|accounts\)_update_state_provider --output-on-failure && cat Testing/Temporary/LastTest.log 

# debugowanie c++ postgresowego z vs code
alias killpostgres='sudo killall -9 postgres;sudo systemctl restart postgresql'

haf/build$ killpostgres; ninja extension.hive_fork_manager hived && sudo ninja install && sudo chown $USER:$USER .ninja_* && ctest -R \(keyauth\|accounts\)_update_state_provider --output-on-failure && cat Testing/Temporary/LastTest.log 

jak zatrzyma się w loopie, to w innej konsoli znajdujemy numer procesu biegnacego w pętli:
$ sudo lsof | grep libhfm

przepisujemy ten numer i puszczamu Debug w VS code z konfiguracja z launch.json:
   {
            "name": "(gdb) Attach",
            "type": "cppdbg",
            "request": "attach",
            "program": "/usr/lib/postgresql/12/bin/postgres",
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                },
                {
                    "description": "Set Disassembly Flavor to Intel",
                    "text": "-gdb-set disassembly-flavor intel",
                    "ignoreFailures": true
                }
            ]
        }

odpali sie attach to proces - wklejamy numer procesu

# tutaja mam pułapke w puszczaniu w extension postgressa
forward-impacted.cpp:
    operation_get_impacted_accounts( const operation& op, flat_set<account_name_type>& result )
    {
      

      static int a = 0;
      while(a)
      {
        a =a;
      }



# printowanie do bocznej tabeli w postgresie
    CREATE OR REPLACE FUNCTION hive.printuj(s TEXT)
        returns void
        LANGUAGE plpgsql
        VOLATILE
    AS
    $BODY$
    BEGIN
        CREATE TABLE IF NOT EXISTS mtk_messages ( message varchar(200) NOT NULL); 
        insert into mtk_messages VALUES(
            s
            );

    END;
    $BODY$
    ;


  

# setting log level in postgress
    SET client_min_messages = warning;


    RAISE warning 'mtk MOJA WIADOMOSC app_state_providers_update';    

    PERFORM hive.printuj(format(
            'hive.app_state_providers_update first_block=%s _last_block=%s _context=%s', _first_block, _last_block, _context
            ));
  
  
  
# odpalanie state providera w nowabazadanych
  w /home/dev/mydes/haf-develop/src/hive_fork_manager/doc/examples/hive_accounts_state_provider.py:

    \# def create_db_engine(pg_port):
    \#     return sqlalchemy.create_engine(
    \#                 "postgresql://alice:test@localhost:{}/psql_tools_test_db".format(pg_port), # this is only example of db
    \#                 isolation_level="READ COMMITTED",
    \#                 pool_size=1,
    \#                 pool_recycle=3600,
    \#                 echo=False)


    def create_db_engine(pg_port):
        return sqlalchemy.create_engine(
                    "postgresql://postgres:postgres@localhost:{}/nowabazadanych".format(pg_port), # this is only example of db
                    isolation_level="READ COMMITTED",
                    pool_size=1,
                    pool_recycle=3600,
                    echo=False)


# setup_db_modified.sh

    #! /bin/bash

    set -x

    SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

    LOG_FILE=setup_db.log
    source "$SCRIPTPATH/common.sh"

    log_exec_params "$@"

    # Script reponsible for execution of all actions required to finish configuration of the database holding a HAF database
    # Linux account executing this script, must be associated to the $DB_ADMIN role which allows to:
    # Unix user executing given script should be a member of specified DB_ADMIN (haf_admin) SQL role, to allow peer authentication
    # - DROP !!! the existing database (if present)
    # - create target database
    # - install the extension there

    print_help () {
        echo "Usage: $0 [OPTION[=VALUE]]..."
        echo
        echo "Allows to create and setup a database to be filled by HAF instance. DROPs already existing database !!!"
        echo "OPTIONS:"
        echo "  --host=VALUE         Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
        echo "  --port=NUMBER        Allows to specify a PostgreSQL operating port (defaults to 5432)"
        echo "  --haf-db-name=NAME   Allows to specify a name of database to store a HAF data"
        echo "  --haf-app-user=NAME  Allows to specify a name of database role to be specified as an APP user of HAF database."
        echo "                       Can be specified multiple times, if user would like to add multiple roles."
        echo "                       Role MUST be earlier created on pointed Postgres instance !!!"
        echo "                       If omitted, defaults to haf_app_admin role."
        echo "  --haf-db-admin=NAME  Allows to specify a name of database admin role having permission to create the database"
        echo "                       and install an exension inside."
        echo "                       Role MUST be earlier created on pointed Postgres instance !!!"
        echo "                       If omitted, defaults to haf_admin role."
        echo "  --help               Display this help screen and exit"
        echo
    }

    DB_NAME="haf_block_log"
    DB_ADMIN="haf_admin"
    HAF_TABLESPACE_NAME="haf_tablespace"

    DEFAULT_DB_USERS=("haf_app_admin")
    DB_USERS=()
    POSTGRES_HOST="/var/run/postgresql"
    POSTGRES_PORT=5432

    while [ $# -gt 0 ]; do
      case "$1" in
        --host=*)
            POSTGRES_HOST="${1#*=}"
            ;;
        --port=*)
            POSTGRES_PORT="${1#*=}"
            ;;
        --haf-db-name=*)
            DB_NAME="${1#*=}"
            ;;
        --haf-app-user=*)
            USER="${1#*=}"
            DB_USERS+=($USER)
            DEFAULT_DB_USERS=() # clear all default users.
            ;;
        --haf-db-admin=*)
            DB_ADMIN="${1#*=}"
            ;;
        --help)
            print_help
            exit 0
            ;;
        -*)
            echo "ERROR: '$1' is not a valid option"
            echo
            print_help
            exit 1
            ;;
        *)
            echo "ERROR: '$1' is not a valid argument"
            echo
            print_help
            exit 2
            ;;
        esac
        shift
    done

    POSTGRES_ACCESS="--host $POSTGRES_HOST --port $POSTGRES_PORT"

    DB_USERS+=("${DEFAULT_DB_USERS[@]}")

    # Seems that -v does not work correctly together with -c. Altough it works fine when -f is used (variable substitution works then)
      
    sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
      DROP DATABASE IF EXISTS $DB_NAME;
      CREATE DATABASE $DB_NAME WITH OWNER $DB_ADMIN TABLESPACE ${HAF_TABLESPACE_NAME};
    EOF

    sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c 'CREATE EXTENSION hive_fork_manager CASCADE;' 

    # sudo -Enu "$DB_ADMIN"   PGPASSWORD=postgres  psql -a $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c 'CREATE EXTENSION hive_fork_manager CASCADE;' 

    for u in "${DB_USERS[@]}"; do
      sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
        GRANT CREATE ON DATABASE $DB_NAME TO $u;
    EOF

    done

# my_start_test_examples.sql
    #!/bin/sh

    set -x

    evaluate_result() {
      local result=$1;

      if [ ${result} -eq 0 ]
      then
        return;
      fi

      echo "FAILED";
      exit 1;
    }

    examples_folder=$1
    test_path=$2;
    setup_scripts_dir_path=$3;
    postgres_port=$4;

    sudo -nu postgres psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -a -f  ./create_db_roles.sql;


    $setup_scripts_dir_path/setup_db.sh --port=$postgres_port  \
      --haf-db-admin="haf_admin" --haf-db-name="psql_tools_test_db" --haf-app-user="alice" --haf-app-user="bob"



    if [ $? -ne 0 ]
    then
      echo "FAILED. Cannot create extension"
      exit 1;
    fi





    psql postgresql://test_hived:test@localhost:$postgres_port/psql_tools_test_db --username=test_hived -a -v ON_ERROR_STOP=on -f ./examples/prepare_data.sql
    evaluate_result $?;


    sudo -nu postgres psql -p $postgres_port -d psql_tools_test_db -v ON_ERROR_STOP=on -a -f  ~/Documents/my_debuggable.sql;

# my_stat_test_examples.sql
    #!/bin/sh

    set -x

    evaluate_result() {
      local result=$1;

      if [ ${result} -eq 0 ]
      then
        return;
      fi

      echo "FAILED";
      exit 1;
    }

    examples_folder=$1
    test_path=$2;
    setup_scripts_dir_path=$3;
    postgres_port=$4;

    sudo -nu postgres psql -p $postgres_port -d postgres -v ON_ERROR_STOP=on -a -f  ./create_db_roles.sql;


    $setup_scripts_dir_path/setup_db.sh --port=$postgres_port  \
      --haf-db-admin="haf_admin" --haf-db-name="psql_tools_test_db" --haf-app-user="alice" --haf-app-user="bob"



    if [ $? -ne 0 ]
    then
      echo "FAILED. Cannot create extension"
      exit 1;
    fi





    psql postgresql://test_hived:test@localhost:$postgres_port/psql_tools_test_db --username=test_hived -a -v ON_ERROR_STOP=on -f ./examples/prepare_data.sql
    evaluate_result $?;


    # python3.8 -m venv .test_examples
    # . ./.test_examples/bin/activate

    # python3 -mpip install --upgrade pip

    # python3 -mpip install \
    #   pexpect==4.8 \
    #   psycopg2==2.9.3 \
    #   sqlalchemy==1.4.18 \
    #   jinja2==2.10

    # ( $test_path $examples_folder $postgres_port)

    # evaluate_result $?;



    #!/usr/bin/env python3

    import sys
    import sqlalchemy

    APPLICATION_CONTEXT = "accounts_ctx"
    SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE = """
        CREATE TABLE IF NOT EXISTS public.trx_histogram(
              day DATE
            , trx INT
            , CONSTRAINT pk_trx_histogram PRIMARY KEY( day ) )
        INHERITS( hive.{} )
        """.format( APPLICATION_CONTEXT )

    def create_db_engine(pg_port):
        return sqlalchemy.create_engine(
                    "postgresql://alice:test@localhost:{}/psql_tools_test_db".format(pg_port), # this is only example of db
                    isolation_level="READ COMMITTED",
                    pool_size=1,
                    pool_recycle=3600,
                    echo=False)

    def prepare_application_data( db_connection ):
            # create a new context only if it not already exists
            exist = db_connection.execute( "SELECT hive.app_context_exists( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone();
            if exist[ 0 ] == False:
                db_connection.execute( "SELECT hive.app_create_context( '{}' )".format( APPLICATION_CONTEXT ) )

            # create and register a table
            db_connection.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE )

            # import accounts state provider
            db_connection.execute( "SELECT hive.app_state_provider_import( 'ACCOUNTS', '{}' )".format( APPLICATION_CONTEXT ) );

    def main_loop( db_connection ):
        # forever loop
        while True:
            # start a new transaction
            with db_connection.begin():
                # get blocks range
                blocks_range = db_connection.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
                accounts = db_connection.execute( "SELECT * FROM hive.{}_accounts ORDER BY id DESC LIMIT 1".format( APPLICATION_CONTEXT ) ).fetchall()

                print( "Blocks range {}".format( blocks_range ) )
                print( "Accounts {}".format( accounts ) )
                (first_block, last_block) = blocks_range;
                # if no blocks are fetched then ask for new blocks again
                if not first_block:
                    continue;

                (first_block, last_block) = blocks_range;

                # check if massive sync is required
                if ( last_block - first_block ) > 100:
                    # Yes, massive sync is required
                    # detach context
                    db_connection.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )

                    # update massivly the application's table - one commit transaction for whole massive edition
                    db_connection.execute( "SELECT hive.app_state_providers_update( {}, {}, '{}' )".format( first_block, last_block, APPLICATION_CONTEXT ) )

                    # attach context and moves it to last synced block
                    db_connection.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) )
                    continue

                # process the first block in range - one commit after each block
                db_connection.execute( "SELECT hive.app_state_providers_update( {}, {}, '{}' )".format( first_block, first_block, APPLICATION_CONTEXT ) )

    def start_application(pg_port):
        engine = create_db_engine(pg_port)
        with engine.connect() as db_connection:
            prepare_application_data( db_connection )
            main_loop( db_connection )

    if __name__ == '__main__':
        try:
            pg_port = sys.argv[1] if (len(sys.argv) > 1) else 5432
            start_application(pg_port)
        except KeyboardInterrupt:
            print( "Break by the user request" )
            pass


# porownywanie recordsetow w Postgresql
raise notice 'NEW_TABLE=%',
(
    SELECT json_agg(t)
    FROM (
            SELECT *
            FROM NEW_TABLE
        ) t
);

raise notice 'OLD_TABLE=%',
(
    select json_agg(t)
    FROM (
            SELECT *
            FROM OLD_TABLE
        ) t
);

raise notice 'outer join comparison=%',
(
    select json_agg(t)
    FROM (
            SELECT S
            FROM NEW_TABLE
                FULL OUTER JOIN old_table USING (S)
            WHERE NEW_TABLE.S IS NULL
                OR OLD_TABLE.S IS NULL
        ) T
);

raise notice 'new_only=%',
(
    select json_agg(t)
    FROM (
            SELECT s,
                'not in old_table' AS note
            FROM new_table
            EXCEPT
            SELECT s,
                'not in old_table' AS note
            FROM old_table
        ) t
);

raise notice 'old_only=%',
(
    select json_agg(t)
    FROM (
            SELECT s,
                'not in new_table' AS note
            FROM old_table
            EXCEPT
            SELECT s,
                'not in new_table' AS note
            FROM new_table
        ) t
);

raise notice 'moja=%', (SELECT json_agg(t)  FROM hive.get_keyauths_operations()t); 


#  comparing unordered arrays and recordsets in postgresql

arr1 TEXT[];
  arr2 TEXT[];
BEGIN


ASSERT unordered_arrays_equal(arr1, arr2), 'Broken hive.get_balance_impacting_operations';

ASSERT unordered_arrays_equal(
    (SELECT array_agg(t.get_balance_impacting_operations)   FROM hive.get_balance_impacting_operations()t),
    (SELECT array_agg(t)   FROM hive.get_balance_impacting_operations_pattern()t) 
), 'Broken hive.get_balance_impacting_operations';

#debugging postgress

cmake -DCMAKE_BUILD_TYPE=Debug  -DCMAKE_CXX_FLAGS="-fdiagnostics-color=always"  -DPOSTGRES_INSTALLATION_DIR=/usr/local/pgsql/bin -GNinja ..

POSTGRES_HOST="127.0.0.1"
POSTGRES_PORT=5433

When running build_and_setup_haf_instance.sh with --use-source-dir do it in source dir

- sudo -u postgres -i
  # running server:
  --postgres@zk-29:~$ /usr/local/pgsql/bin/pg_ctl -D /usr/local/pgsql/data -l logfile start

  # stopping server:
  postgres@zk-29:~$ /usr/local/pgsql/bin/pg_ctl -D /usr/local/pgsql/data -l logfile stop

- kill postgress:
alias killpostgres='sudo killall -9 postgres;sudo systemctl restart postgresql'

rwxrwxrwx 1 root root 25 Oct 17 21:52 psql -> /usr/local/pgsql/bin/psql*
lrwxrwxrwx 1 root root 25 Oct 17 21:50 psql_new -> /usr/local/pgsql/bin/psql*
lrwxrwxrwx 1 root root 37 Aug 24  2020 psql_old -> ../share/postgresql-common/pg_wrapper*


# printing BTW of fixing extract_set_witness_properties.sql
    raise notice 'moja=%', (SELECT json_agg(t)  FROM (




        SELECT (
            
                
                hive.extract_set_witness_properties(
                    json_build_array(
                        json_build_array(
                            pname,
                            pvalue
                        )
                    ) ::TEXT
                ) :: TEXT,
                    pattern::TEXT,
                hive.extract_set_witness_properties(
                    json_build_array(
                        json_build_array(
                            pname,
                            pvalue
                        )
                    ) ::TEXT
                ) :: TEXT = pattern::text                    
                
             
        ) 
        FROM samples_for_extract_set_witness_properties
        
    
    
    
    )
        t);     

# building and running dockerized instance
1. Budowa image pod dokeryzowany HAF: 
cd do zrodla
./ci-helpers/build_instance.sh docker_instance_MTTK ~/dockerized_from_mateusz_zebrak/haf  registry.gitlab.syncad.com/hive/haf/ 

2. Stworzenie data-dir : 
 # cd powyzej zrodel

cd ../..
mkdir data_dir
cd data_dir/
mkdir blockchain
cd blockchain/
cp -i ~/Documents/block_log.5M  .
mv block_log.5M block_log
cd ..
chmod -R a+w data_dir/
cd data_dir/

docker ps 
 
3. Uruchomienie node'a z replayem: 

./scripts/run_hived_img.sh registry.gitlab.syncad.com/hive/haf/instance:instance-docker-instance-mttk --name=moja-nowa-nazwa-kontenera --data-dir=/home/dev/dockerized_from_mateusz_zebrak/data_dir/  --shared-file-dir=/home/dev/dockerized_from_mateusz_zebrak/data_dir/ --docker-option="-p 25432:5432" --replay --stop-replay-at-block=5000000


drwxrwxr-x  4 dev dev 4.0K Oct 20 15:01 ./
drwxr-xr-x 38 dev dev 4.0K Oct 20 13:56 ../
drwxrwxrwx  5 dev dev 4.0K Oct 20 15:05 data_dir/
drwxrwxr-x 11 dev dev 4.0K Oct 20 15:05 haf/

dev@zk-29:~/dockerized_from_mateusz_zebrak/data_dir$ tree .
.
├── blockchain
│   ├── block_log
│   └── block_log.artifacts
├── config.ini
├── haf_db_store
│   ├── pgdata [error opening dir]
│   └── tablespace [error opening dir]
├── hived.log
├── logs
│   └── p2p
└── shared_memory.bin

4. Połączenie z bazą danych z hosta:
psql -h localhost -p 25432 -d haf_block_log -U haf_app_admin 


