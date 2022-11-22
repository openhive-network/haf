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

def db2text(databasename, session):

    schema_filename = databasename + '_schema.txt'
    data_filename = databasename + '_data.txt'


    subprocess.call(f'rm {schema_filename}', shell=True)
    subprocess.call(f'rm {data_filename}', shell=True)


    subprocess.call(rf"psql -d {databasename} -c '\dn'  > {schema_filename}", shell=True)
    subprocess.call(rf"psql -d {databasename} -c '\d hive.*' >> {schema_filename}", shell=True)
    # subprocess.call(rf"psql -d {databasename} -c '\d *' >> {schema_filename}", shell=True)

    def dbobjects2text(table_or_view):
        pattern = re.compile(rf'{table_or_view} "(.*)"')
        tables = re.findall(pattern, open(schema_filename).read())
        print(tables)

        for table in tables:
            hive_prefix = 'hive.'
            if table.startswith(hive_prefix):
                table_wo_prefix = table[len(hive_prefix):]
            else:
                table_wo_prefix = table
            subprocess.call(f"echo {table_or_view} {table} >> {data_filename}", shell=True)
            # https://wiki.postgresql.org/wiki/Retrieve_primary_key_columns
            # subprocess.call(f"""psql -d {databasename} -c  "SELECT a.attname, format_type(a.atttypid, a.atttypmod) AS data_type             FROM   pg_index i             JOIN   pg_attribute a ON a.attrelid = i.indrelid                                 AND a.attnum = ANY(i.indkey)             WHERE  i.indrelid = '{table}'::regclass             AND    i.indisprimary;"  >> {data_filename}""", shell=True)

            # subprocess.call(f"""psql -d {databasename} -c "SELECT * FROM information_schema.columns  WHERE table_schema = 'hive' AND table_name   = '{table}';"  >> {data_filename}""", shell=True)
            recordset = session.execute(f"SELECT column_name FROM information_schema.columns  WHERE table_schema = 'hive' AND table_name   = '{table_wo_prefix}';")

            
            order_by = ', '.join([e[0] for e in (recordset)])
            
            execution_string  = f"psql -d {databasename} -c 'SELECT * FROM {table} ORDER BY {order_by}' >> {data_filename}"
            print('execution_string=',execution_string)
            subprocess.call(execution_string, shell=True)

    
    dbobjects2text('Table')
    dbobjects2text('View')

    return schema_filename, data_filename



def comparethesetexts_equal(fileset1, fileset2):
    def comparefiles(file1, file2):
        difffilename = f'diff_{file1}_{file2}.diff'
        subprocess.call(f"diff {file1} {file2} > {difffilename}", shell=True)
        s = open(difffilename).read()
        filelength = len(s)
        if filelength:
            print(f"Error: database dumps not equal ({file1}, {file2}), diff file:\n{s}")
        return filelength

    diff_file_lengths = 0
    for file1, file2 in zip(fileset1, fileset2):
        print(f'meld {os.path.realpath(file1)} {os.path.realpath(file2)}')
        diff_file_lengths += comparefiles(file1, file2)

    return diff_file_lengths == 0


def shell(command):
    subprocess.call(command, shell=True)


if __name__ == '__main__':
    db2text('haf_block_log')

START_TEST_BLOCK = 108

def test_pg_dump(prepared_networks_and_database, database):
    # db2text('haf_block_log')
    tt.logger.info(f'Start test_compare_forked_node_database')

    # GIVEN
    networks, session, Base = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')

    source_session, Base_ref = database('postgresql:///haf_block_log_ref')

    print(source_session.bind)


    blocks = Base.classes.blocks
    transactions = Base.classes.transactions
    operations = Base.classes.operations

    reference_node = create_node_with_database(networks['Alpha'], source_session.get_bind().url)

    
    blocklog_directory = get_blocklog_directory()
    
# mttk todo  usun tu witness extension
    block_log = tt.BlockLog(blocklog_directory/'block_log')

    reference_node.run(wait_for_live=False, replay_from=block_log, stop_at_block= 105)


# time pg_restore -Fc -j 6 -v -U hive -d hive hivemind-31a03fa6-20201116.dump
# time pg_dump -Fc hive -U hive -d hive -v -f hivemind-revisionsynca-revisionupgradeu-data.dump
# oczywiście to przykłady z użycia starej bazy hiveminda (hive)

    # subprocess.call(f'pg_dump {(source_session.bind.url)} -Fp -v  > dump.sql', shell=True, stdout =f)
    print('MTTK before PG_DUMP extension')
    def pg_dump(db_name):
        shell(f'pg_dump  -Fc   -d {db_name} -f adump.Fcsql')

    pg_dump(source_session.bind.url)

    
    def pg_restore_to_show_files_only():
        shell(f'pg_restore                     --disable-triggers  -Fc -f adump.sql           adump.Fcsql')
        shell(f'pg_restore --section=pre-data  --disable-triggers  -Fc -f adump-data.sql      adump.Fcsql')
        shell(f'pg_restore --section=data      --disable-triggers  -Fc -f adump-data.sql      adump.Fcsql')
        shell(f'pg_restore --section=post-data --disable-triggers  -Fc -f adump-post-data.sql adump.Fcsql')

    pg_restore_to_show_files_only()



    source_db = source_session.bind.url.database
    target_db = 'adb'
    # restore pre-data
    subprocess.call(f"""psql -U dev -d postgres \
        -c \
        "SELECT pg_terminate_backend(pg_stat_activity.pid) 
        FROM pg_stat_activity 
        WHERE pg_stat_activity.datname = '{target_db}' 
            AND pid <> pg_backend_pid();"
    """,
     shell=True)
    subprocess.call(f"psql -d postgres -c 'DROP DATABASE {target_db};'", shell=True)
    subprocess.call(f"psql -d postgres -c 'CREATE DATABASE {target_db};'", shell=True)

    print('MTTK before real restore of pre-data')
    subprocess.call(f"pg_restore  -v --section=pre-data  -Fc -d {target_db}   adump.Fcsql", shell=True)

    # delete status table contntents
    ##### subprocess.call(f"psql  -d {target_db} -c 'DELETE from hive.irreversible_data;'", shell=True)

    print('MTTK before real restore of data')
    #restore data
    subprocess.call(f"pg_restore --disable-triggers --section=data  -v -Fc  -d {target_db}   adump.Fcsql", shell=True)

    print('MTTK before real restore of post-data')
    #restore post-data
    subprocess.call(f"pg_restore --disable-triggers --section=post-data  -Fc  -d {target_db}   adump.Fcsql", shell=True)

    #is ok ?

    #subprocess.call(f"psql  -d {target_db} -c 'SELECT COUNT(*) FROM hive.blocks", shell=True)
    #session2, Base_ref2 = database('postgresql:///adb')    

    engine = sqlalchemy.create_engine('postgresql:///adb', echo=False, poolclass=NullPool)
    # with engine.connect() as connection:
    #     connection.execute('CREATE EXTENSION hive_fork_manager CASCADE;')

    # with engine.connect() as connection:
    #     connection.execute('SET ROLE hived_group')

    Session = sessionmaker(bind=engine)
    session2 = Session()

    metadata = sqlalchemy.MetaData(schema="hive")
    Base2 = automap_base(bind=engine, metadata=metadata)
    Base2.prepare(reflect=True)



    blocks2 = Base2.classes.blocks

    block_count = session2.query(blocks2).count()
    assert(block_count == 105)

    irreversible_data = Base2.classes.irreversible_data

    reco = session2.query(irreversible_data).one()
    print(reco)

    
    
    no_differences = comparethesetexts_equal(db2text(source_db, session), db2text(target_db, session2))
    assert(no_differences)


