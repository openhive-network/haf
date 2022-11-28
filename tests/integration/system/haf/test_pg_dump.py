from __future__ import annotations

import subprocess
from typing import TYPE_CHECKING


import test_tools as tt
from local_tools import make_fork, wait_for_irreversible_progress, run_networks, create_node_with_database, get_blocklog_directory

if TYPE_CHECKING:
    from sqlalchemy.orm.session import Session
    from sqlalchemy.engine.row import Row


RESTORE_FROM_TOC = True


def test_pg_dump(database):
    tt.logger.info(f'Start test_pg_dump')

    # GIVEN
    source_session, source_db_name = prepare_source_db(database)
    pg_dump(source_db_name)

    target_session, _ = database('postgresql:///adb')
    target_db_name = target_session.bind.url

    # WHEN
    pg_restore(target_db_name)

    # THEN 

    compare_databases(source_session,  target_session)

    compare_psql_tool_dumped_schemas(source_session,  target_session)

    
def prepare_source_db(database) -> None:
    source_session, _ = database('postgresql:///haf_block_log')
    source_db_name = source_session.get_bind().url
    reference_node = create_node_with_database(url = source_db_name)
    blocklog_directory = get_blocklog_directory()
    block_log = tt.BlockLog(blocklog_directory/'block_log')
    reference_node.run(replay_from=block_log, stop_at_block= 105, exit_before_synchronization=True)
    source_db_name = source_session.bind.url
    return source_session, source_db_name


def create_psql_tool_dumped_schema(session: Session) -> str:
    databasename = session.bind.url.database
    schema_filename = databasename + '_schema.txt'

    shell(rf"psql -d {databasename} -c '\dn'  > {schema_filename}")
    shell(rf"psql -d {databasename} -c '\d hive.*' >> {schema_filename}")

    return open(schema_filename).read()

def pg_dump(db_name : str) -> None:
    shell(f'pg_dump -Fc -d {db_name} -f adump.Fcsql')


def pg_restore(target_db_name: str) -> None:
    """ For debugging purposes it is sometimes valuable to display dump contents like this:
    pg_restore --section=pre-data  --disable-triggers  -Fc -f adump-pre-data.sql  adump.Fcsql
    """
    db_name = target_db_name.database
    if RESTORE_FROM_TOC:
        toc_filename = f'{db_name}.toc'
        toc_filename2 = f'{db_name}.toc2'

        print (f'meld {toc_filename} {toc_filename2}')

        shell(f"pg_restore --exit-on-error -l adump.Fcsql > {toc_filename}")

        shell(fr"grep -v '[0-9]\+; [0-9]\+ [0-9]\+ SCHEMA - hive'  {toc_filename} | grep -v '[0-9]\+; [0-9]\+ [0-9]\+ POLICY hive' > {toc_filename2} ")
        
        #shell(f"pg_restore --exit-on-error --section=pre-data -L {toc_filename2} -d {target_db_name}   adump.Fcsql")
        #shell(f"pg_restore --exit-on-error --disable-triggers -L {toc_filename2} --section=data -Fc  -d {target_db_name}   adump.Fcsql")

        shell(f"pg_restore --exit-on-error --single-transaction  -L {toc_filename2} -d {target_db_name} adump.Fcsql")
    else:
       # restore pre-data
        shell(f"pg_restore --section=pre-data  -Fc -d {target_db_name}   adump.Fcsql")

        #restore data
        shell(f"pg_restore --disable-triggers --section=data -Fc  -d {target_db_name}   adump.Fcsql")

        #restore post-data is not needed by far 

def compare_databases(source_session: Session, target_session: Session) -> None:
    ask_for_tables_and_views_sql = f"SELECT table_name FROM information_schema.tables WHERE table_schema = 'hive' ORDER BY table_name"
    source_tables = query_col(source_session, ask_for_tables_and_views_sql)
    target_tables = query_col(target_session, ask_for_tables_and_views_sql)

    assert source_tables ==  target_tables
    
    for table in source_tables:
        source_recordset = take_table_contents(source_session, table)
        target_recordset = take_table_contents(target_session, table)
        assert source_recordset == target_recordset, f"ERROR: in table_or_view: {table}"

        
def take_table_contents(session: Session, table: str) -> list[Row]:
    recordset = query_all(session, f"SELECT column_name FROM information_schema.columns  WHERE table_schema = 'hive' AND table_name   = '{table}';")
    columns = ', '.join([e[0] for e in (recordset)])
    return query_all(session, f"SELECT * FROM hive.{table} ORDER BY {columns}")


def compare_psql_tool_dumped_schemas(source_session: Session, target_session: Session) -> None:
    source_schema = create_psql_tool_dumped_schema(source_session)
    target_schema = create_psql_tool_dumped_schema(target_session)

    assert source_schema == target_schema

    
def create_psql_tool_dumped_schema(session: Session) -> str:
    databasename = session.bind.url.database
    schema_filename = databasename + '_schema.txt'

    shell(rf"psql -d {databasename} -c '\dn'  > {schema_filename}")
    shell(rf"psql -d {databasename} -c '\d hive.*' >> {schema_filename}")

    return open(schema_filename).read()


def shell(command: str) -> None:
    subprocess.call(command, shell=True)

    
def query_col(session: Session, s: str) -> list[str]:
    return [e[0] for e in session.execute(s)]


def query_all(session: Session, s: str) -> list[Row]:
    return [e for e in session.execute(s)]
