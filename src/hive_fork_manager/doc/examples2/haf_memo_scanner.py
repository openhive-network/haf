#!/usr/bin/python3

#Storing all transfers that were detected as memo

import os
import json
import re

from haf_utilities import helper, argument_parser, args_container
from haf_base import application

class callback_handler_memo_scanner():

  def __init__(self, searched_item, schema_name):
    self.app            = None
    self.searched_item  = searched_item
    self.schema_name    = schema_name

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

    self.insert_into_memos             = []
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

def main():
  _parser = argument_parser_ex()
  _parser.parse()

  _schema_name = "memo_scanner"

  _callbacks      = callback_handler_memo_scanner(_parser.get_searched_item(), _schema_name)
  _app            = application(args_container(_parser.get_url(), _parser.get_range_blocks(), _parser.get_massive_threshold()), _schema_name + "_app", _callbacks)
  _callbacks.app  = _app

  _app.process()

if __name__ == '__main__':
  main()
