import subprocess
import sqlalchemy
from sqlalchemy.pool import NullPool
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.automap import automap_base


import test_tools as tt

from local_tools import make_fork, wait_for_irreversible_progress, run_networks, create_node_with_database, get_blocklog_directory


import re

#once the errrors disappear we could use single pg_restore command
ERRRORS_IN_CREATE_POLICY = True

START_TEST_BLOCK = 108

def test_pg_dump(prepared_networks_and_database):
    tt.logger.info(f'Start test_pg_dump')

    # GIVEN
    source_session, source_db_name = prepare_source_db(prepared_networks_and_database)
    pg_dump(source_db_name)

    pg_restore_to_show_files_only()

    target_db_name = 'adb'
    wipe_db(target_db_name)

    # WHEN
    pg_restore(target_db_name)

    # THEN 
    target_session, target_Base = access_target_db(target_db_name)
    block_count = target_session.query(target_Base.classes.blocks).count()
    assert(block_count == 105)

    compare_databases(source_session,  target_session)

    
def prepare_source_db(prepared_networks_and_database):
    networks, source_session, Base = prepared_networks_and_database
    reference_node = create_node_with_database(networks['Alpha'], source_session.get_bind().url)
    blocklog_directory = get_blocklog_directory()
    # mttk todo  usun tu witness extension
    block_log = tt.BlockLog(blocklog_directory/'block_log')
    reference_node.run(wait_for_live=False, replay_from=block_log, stop_at_block= 105)
    source_db_name = source_session.bind.url
    return source_session, source_db_name


def pg_dump(db_name):
    shell(f'pg_dump  -Fc   -d {db_name} -f adump.Fcsql')

def pg_restore_to_show_files_only():
    shell(f'pg_restore                     --disable-triggers  -Fc -f adump.sql           adump.Fcsql')
    shell(f'pg_restore --section=pre-data  --disable-triggers  -Fc -f adump-data.sql      adump.Fcsql')
    shell(f'pg_restore --section=data      --disable-triggers  -Fc -f adump-data.sql      adump.Fcsql')
    shell(f'pg_restore --section=post-data --disable-triggers  -Fc -f adump-post-data.sql adump.Fcsql')
    

def wipe_db(db_name):
    shell(f"""psql -U dev -d postgres \
        -c \
        "SELECT pg_terminate_backend(pg_stat_activity.pid) 
        FROM pg_stat_activity 
        WHERE pg_stat_activity.datname = '{db_name}' 
            AND pid <> pg_backend_pid();"
    """)
    shell(f"psql -d postgres -c 'DROP DATABASE {db_name};'")
    shell(f"psql -d postgres -c 'CREATE DATABASE {db_name};'")

    
def pg_restore(target_db_name):
    if ERRRORS_IN_CREATE_POLICY:
        # restore pre-data
        shell(f"pg_restore  -v --section=pre-data  -Fc -d {target_db_name}   adump.Fcsql")

        #restore data
        shell(f"pg_restore --disable-triggers --section=data  -v -Fc  -d {target_db_name}   adump.Fcsql")

        #restore post-data
        shell(f"pg_restore --disable-triggers --section=post-data  -Fc  -d {target_db_name}   adump.Fcsql")
    else:
        shell(f"pg_restore  -v --single-transaction  -Fc -d {target_db_name}   adump.Fcsql")


def access_target_db(target_db_name):
    engine = sqlalchemy.create_engine(f'postgresql:///{target_db_name}', echo=False, poolclass=NullPool)

    Session = sessionmaker(bind=engine)
    session = Session()
    metadata = sqlalchemy.MetaData(schema="hive")
    Base = automap_base(bind=engine, metadata=metadata)
    Base.prepare(reflect=True)

    return session, Base


def compare_databases(source_session, target_session):
    ask_for_tables_and_vies_sql = f"select table_name from information_schema.tables where table_schema = 'hive'"
    source_tables = execute_sql_one_column(source_session, ask_for_tables_and_vies_sql)
    target_tables = execute_sql_one_column(target_session, ask_for_tables_and_vies_sql)

    source_tables.sort()
    target_tables.sort()

    assert source_tables ==  target_tables

    for table in source_tables:
        ask_for_table_contents_sql = f"SELECT * FROM hive.{table}"
        source_recordset = execute_sql(source_session, ask_for_table_contents_sql)
        target_recordset = execute_sql(target_session, ask_for_table_contents_sql)

        assert source_recordset == target_recordset, f"ERROR: in table: {table}"

        
def shell(command):
    subprocess.call(command, shell=True)


def execute_sql_one_column(session, s):
    return [e[0] for e in session.execute(s)]


def execute_sql(session, s):
    return [e for e in session.execute(s)]

