#!/usr/bin/python3

#Storing all changes of account creation fee

import os
import json
import re

from haf_utilities import helper, argument_parser, args_container
from haf_base import application

class callback_handler_account_creation_fee_follower:

  def __init__(self, schema_name):
    self.app    = None
    self.schema_name = schema_name

  def prepare_sql(self):
    #SQL queries
    self.create_history_table = '''
      CREATE SCHEMA IF NOT EXISTS {};
      CREATE TABLE IF NOT EXISTS {}.fee_history
      (
        block_num INTEGER NOT NULL,
        witness_id INTEGER NOT NULL,
        fee VARCHAR(200) NOT NULL
      )INHERITS( hive.{} );
    '''.format(self.schema_name, self.schema_name, self.app.app_context)

    self.insert_into_history = []
    self.insert_into_history.append( "INSERT INTO {}.fee_history(block_num, witness_id, fee) SELECT T.block_num, A.id, T.fee FROM ( VALUES".format(self.schema_name) )
    self.insert_into_history.append( " ( {}, '{}', {} )" )
    self.insert_into_history.append( " ) T(block_num, witness_name, fee) JOIN hive.{}_accounts_view A ON T.witness_name = A.name;".format(self.app.app_context) )

    self.get_witness_updates = '''
      SELECT block_num, body
      FROM hive.{}_operations_view o
      JOIN hive.operation_types ot ON o.op_type_id = ot.id
      WHERE ot.name = 'hive::protocol::witness_update_operation' AND block_num >= {} and block_num <= {}
    '''

  def checker(self):
    assert self.app is not None, "an app must be initialized"

  def pre_none_ctx(self):
    helper.info("Creation SQL tables: (PRE-NON-CTX phase)")
    self.checker()

    self.prepare_sql()
    _result = self.app.exec_query(self.create_history_table)

  def pre_is_ctx(self):
    pass

  def pre_always(self):
    pass

  def run_impl(self, low_block, high_block):
    _query = self.get_witness_updates.format(self.app.app_context, low_block, high_block)
    _result = self.app.exec_query_all(_query)

    _values = []
    helper.info("For blocks {}:{} found {} witness updates", low_block, high_block, len(_result))

    for record in _result:
      _op = json.loads(record[1])

      if 'value' in _op:
        _value = _op['value']

      _owner                = None
      _account_creation_fee = None

      if 'owner' in _value:
        _owner = _value['owner']
        if 'props' in _value and 'account_creation_fee' in _value['props']:
          _account_creation_fee = _op['value']['props']['account_creation_fee']

      if _owner is not None and _account_creation_fee is not None:
        __account_creation_fee = helper.escape_characters(json.dumps(_account_creation_fee))
        _values.append(self.insert_into_history[1].format(record[0], _owner, __account_creation_fee))

    helper.execute_complex_query(self.app, _values, self.insert_into_history)

  def run(self, low_block, high_block):
    helper.info("processing incoming data: (RUN phase)")
    self.checker()

    self.run_impl(low_block, high_block)

  def post(self): 
    pass

def main():
  _parser = argument_parser()
  _parser.parse()

  _schema_name = "fee_follower"

  _callbacks      = callback_handler_account_creation_fee_follower(_schema_name)
  _app            = application(args_container(_parser.get_url(), _parser.get_range_blocks(), _parser.get_massive_threshold()), _schema_name + "_app", _callbacks)
  _callbacks.app  = _app

  _app.process()

if __name__ == '__main__':
  main()
