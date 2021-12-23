from pathlib import Path

from test_tools import logger, Wallet, Asset
from local_tools import get_irreversible_block, get_head_block, run_networks
from threading import Thread


START_TEST_BLOCK = 108

#!/usr/bin/python3

#Storing all transfers that were detected as memo

import os
import json
import re
import sys


from haf_utilities import helper, argument_parser, args_container
from haf_base import haf_base, application

class sql_memo_scanner(haf_base):

  def __init__(self, searched_item, schema_name):
    super().__init__()
    self.app                = None
    self.searched_item      = searched_item
    self.schema_name        = schema_name
    self.create_memo_table  = ''
    self.get_transfers      = ''
    self.insert_into_memos  = []

  def prepare_sql(self):
    #SQL queries
    self.create_memo_table = '''
      CREATE SCHEMA IF NOT EXISTS {};
      CREATE TABLE IF NOT EXISTS {}.memos (
        block_num INTEGER NOT NULL,
        trx_in_block INTEGER NOT NULL,
        op_pos INTEGER NOT NULL,
        memo_content VARCHAR(512) NOT NULL
      )INHERITS( hive.{} );

      ALTER TABLE {}.memos ADD CONSTRAINT memos_pkey PRIMARY KEY ( block_num, trx_in_block, op_pos );
    '''.format(self.schema_name, self.schema_name, self.app.app_context, self.schema_name)

    self.insert_into_memos.append( "INSERT INTO {}.memos(block_num, trx_in_block, op_pos, memo_content) VALUES".format(self.schema_name) )
    self.insert_into_memos.append( " ({}, {}, {}, '{}')" )
    self.insert_into_memos.append( " ;" )

    self.get_transfers = '''
      SELECT block_num, trx_in_block, op_pos, body
      FROM hive.{}_operations_view o
      JOIN hive.operation_types ot ON o.op_type_id = ot.id
      WHERE ot.name = 'hive::protocol::transfer_operation' AND block_num >= {} and block_num <= {}
    '''

  def checker(self):
    assert self.app is not None, "an app must be initialized"

  def pre_none_ctx(self):
    helper.info("Creation SQL tables: (PRE-NON-CTX phase)")
    self.checker()

    self.prepare_sql()
    _result = self.app.exec_query(self.create_memo_table.format(self.app.app_context))

  def pre_is_ctx(self):
    pass

  def pre_always(self):
    pass

  def run(self, low_block, high_block):
    helper.info("processing incoming data: (RUN phase)")
    self.checker()

    _query = self.get_transfers.format(self.app.app_context, low_block, high_block)
    _result = self.app.exec_query_all(_query)

    _values = []
    helper.info("For blocks {}:{} found {} transfers".format(low_block, high_block, len(_result)))
    for record in _result:
      _op = json.loads(record[3])
      if 'value' in _op and 'memo' in _op['value']:
        _memo = _op['value']['memo']

        if re.search(self.searched_item, _memo, re.IGNORECASE) is not None:
          _values.append(self.insert_into_memos[1].format(record[0], record[1], record[2], _memo))

    helper.execute_complex_query(self.app, _values, self.insert_into_memos)

  def post(self): 
    pass

class argument_parser_ex(argument_parser):
  def __init__(self):
    super().__init__()
    self.parser.add_argument("--searched-item", type = str, required = True, help = "Part of memo that should be found")

  def get_searched_item(self):
    return self.args.searched_item

def main(session):
  _parser = argument_parser_ex()
  _parser.parse()

  _schema_name      = "memo_scanner"
  helper.logger = None
  _sql_memo_scanner = sql_memo_scanner(_parser.get_searched_item(), _schema_name)
  helper.logger = None
  _app              = application(session.get_bind().url, 1000, 1, _schema_name + "_app", _sql_memo_scanner)
  helper.logger = None

  _app.process()



def test_memo_scanner(world_with_witnesses_and_database):
    logger.info(f'Start test_memo_scanner')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')

    # WHEN

    # exist = session.execute( "SELECT hive.app_context_exists( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    # if exist[ 0 ] == False:
    #     session.execute( "SELECT hive.app_create_context( '{}' )".format( APPLICATION_CONTEXT ) )

    # # create and register a table
    # session.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE )

    # # create SQL function to do the application's task
    # session.execute( SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION )
    # session.commit()

    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    wallet = Wallet(attach_to=node_under_test)
    def thread_func():
        #if random.choice([True, True, False]):
        count = 0
        from random import choice
        while True:
            if choice([True, False]):
                wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), f'dummy transfer operation number {count}')
            else:
                wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), f'fake transfer operation number {count}')
            count = count + 1

            logger.info(f'------------------ sent {count} transaction by {wallet}')
    Thread(daemon=True, target=thread_func).start()

    head_block = get_head_block(node_under_test)
    irreversible = get_irreversible_block(node_under_test)
    while True:pass

    # session.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )
    # session.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, irreversible ) )
    # _schema_name      = "memo_scanner"
    # _sql_memo_scanner = sql_memo_scanner("dummy", _schema_name)
    # helper.logger = None
    # _app              = application(args_container(session.get_bind().url, 1000, 1), _schema_name + "_app", _sql_memo_scanner)
    # _app.process()
    # while True:
    #     pass

    def thread_func2():
        _schema_name      = "memo_scanner"
        _sql_memo_scanner = sql_memo_scanner("dummy", _schema_name)
        _app              = application(args_container(session.get_bind().url, 1000, 1), _schema_name + "_app", _sql_memo_scanner)
        _sql_memo_scanner.total_run()
        
    Thread(daemon=True, target=thread_func2).start()

    # THEN
    logger.info("Application created, infinite loop")
    while True:

        head_block = get_head_block(node_under_test)
        irreversible = get_irreversible_block(node_under_test)
        if head_block > 130:
            break


        # blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
        # session.commit()
        # (first_block, last_block) = blocks_range
        # logger.info( "Blocks range {}".format( blocks_range ) )
        # # if no blocks are fetched then ask for new blocks again
        # if not first_block:
        #     continue

        # hist = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
        # session.commit()
        # logger.info( "Histogram: {}\n".format( hist ) )
        # session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
        # session.commit()
        # hist = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
        # session.commit()
        # logger.info( "Histogram: {}\n".format( hist ) )

        # max_block_blocks_view = session.execute( "SELECT COUNT(1) FROM hive.blocks_view").fetchone()
        # session.commit()
        # logger.info( "max_block from hive.blocks_view: {}\n".format( max_block_blocks_view ) )
        # max_block_transactions_view = session.execute( "SELECT COUNT(1) FROM hive.transactions_view").fetchone()
        # session.commit()
        # logger.info( "max_block from hive.transactions_view: {}\n".format( max_block_transactions_view ) )
        # trx_histogram_max_block = session.execute( "SELECT * FROM hive.contexts").fetchone()
        # session.commit()
        # logger.info( "trx_histogram_max_block: {}\n".format( trx_histogram_max_block ) )
        # session.commit()
        # logger.info( "contexts: {}\n".format( trx_histogram_max_block ) )

