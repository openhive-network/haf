import os
import subprocess
import pytest
import sqlalchemy
from sqlalchemy.pool import NullPool
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.automap import automap_base

#mttk todo  Jeszcze w C sa irreversible_data bez _the_table
#mttk new function  in local_tools 
#mttk komentarz wszystkie table maja byc puste na poczatku

from pathlib import Path

import test_tools as tt

from local_tools import make_fork, wait_for_irreversible_progress, run_networks, create_node_with_database, get_blocklog_directory


import re


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

    no_differences = comparethesetexts_equal(db2text(source_session), db2text(target_session))
    assert(no_differences)

    
def prepare_source_db(prepared_networks_and_database):
    networks, source_session, Base = prepared_networks_and_database
    reference_node = create_node_with_database(networks['Alpha'], source_session.get_bind().url)
    blocklog_directory = get_blocklog_directory()
    # mttk todo  usun tu witness extension
    block_log = tt.BlockLog(blocklog_directory/'block_log')
    reference_node.run(wait_for_live=False, replay_from=block_log, stop_at_block= 105)
    source_db_name = source_session.bind.url
    return source_session, source_db_name

# time pg_restore -Fc -j 6 -v -U hive -d hive hivemind-31a03fa6-20201116.dump
# time pg_dump -Fc hive -U hive -d hive -v -f hivemind-revisionsynca-revisionupgradeu-data.dump
# oczywiście to przykłady z użycia starej bazy hiveminda (hive)
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
    print('MTTK before real restore of pre-data')
    # restore pre-data
    shell(f"pg_restore  -v --section=pre-data  -Fc -d {target_db_name}   adump.Fcsql")

    print('MTTK before real restore of data')
    #restore data
    shell(f"pg_restore --disable-triggers --section=data  -v -Fc  -d {target_db_name}   adump.Fcsql")

    print('MTTK before real restore of post-data')
    #restore post-data
    shell(f"pg_restore --disable-triggers --section=post-data  -Fc  -d {target_db_name}   adump.Fcsql")

def access_target_db(target_db_name):
    engine = sqlalchemy.create_engine(f'postgresql:///{target_db_name}', echo=False, poolclass=NullPool)

    Session = sessionmaker(bind=engine)
    session = Session()
    metadata = sqlalchemy.MetaData(schema="hive")
    Base = automap_base(bind=engine, metadata=metadata)
    Base.prepare(reflect=True)

    return session, Base

    
def comparethesetexts_equal(fileset1, fileset2):
    diff_file_lengths = 0
    for file1, file2 in zip(fileset1, fileset2):
        print(f'meld {os.path.realpath(file1)} {os.path.realpath(file2)}')
        diff_file_lengths += comparefiles(file1, file2)

    return diff_file_lengths == 0

def comparefiles(file1, file2):
    difffilename = f'diff_{file1}_{file2}.diff'
    subprocess.call(f"diff {file1} {file2} > {difffilename}", shell=True)
    s = open(difffilename).read()
    filelength = len(s)
    if filelength:
        print(f"Error: database dumps not equal ({file1}, {file2}), diff file:\n{s}")
    return filelength

def db2text(session):
    databasename = session.bind.url.database
    schema_filename = databasename + '_schema.txt'
    data_filename = databasename + '_data.txt'


    shell(f'rm {schema_filename}')
    shell(f'rm {data_filename}')


    shell(rf"psql -d {databasename} -c '\dn'  > {schema_filename}")
    shell(rf"psql -d {databasename} -c '\d hive.*' >> {schema_filename}")
    
    dbobjects2text('Table', databasename, session, schema_filename, data_filename)
    dbobjects2text('View', databasename, session, schema_filename, data_filename)

    return schema_filename, data_filename

def dbobjects2text(table_or_view, databasename, session, schema_filename, data_filename):
    pattern = re.compile(rf'{table_or_view} "(.*)"')
    db_relations = re.findall(pattern, open(schema_filename).read())
    print(db_relations)

    tables_recordset = session.execute(f"select table_name from information_schema.tables where table_schema = 'hive';")

    for table in tables_recordset:
        print(f'{table_or_view}  table_recordset={table}')

    for table in db_relations:
        print(f'{table_or_view}  table={table}')
    


    for table in db_relations:
        hive_prefix = 'hive.'
        if table.startswith(hive_prefix):
            table_wo_prefix = table[len(hive_prefix):]
        else:
            table_wo_prefix = table
        shell(f"echo {table_or_view} {table} >> {data_filename}")
        # https://wiki.postgresql.org/wiki/Retrieve_primary_key_columns
        # shell(f"""psql -d {databasename} -c  "SELECT a.attname, format_type(a.atttypid, a.atttypmod) AS data_type             FROM   pg_index i             JOIN   pg_attribute a ON a.attrelid = i.indrelid                                 AND a.attnum = ANY(i.indkey)             WHERE  i.indrelid = '{table}'::regclass             AND    i.indisprimary;"  >> {data_filename}""", shell=True)

        # https://dba.stackexchange.com/questions/22362/list-all-columns-for-a-specified-table
        recordset = session.execute(f"SELECT column_name FROM information_schema.columns  WHERE table_schema = 'hive' AND table_name   = '{table_wo_prefix}';")

        
        columns = ', '.join([e[0] for e in (recordset)])
        
        execution_string  = f"psql -d {databasename} -c 'SELECT * FROM {table} ORDER BY {columns}' >> {data_filename}"
        print(f'{execution_string=}')
        shell(execution_string)



def shell(command):
    subprocess.call(command, shell=True)


    

