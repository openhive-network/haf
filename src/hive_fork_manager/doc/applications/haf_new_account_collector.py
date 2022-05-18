#!/usr/bin/python3

import os
import json
import sys

sys.path.append(os.path.dirname(__file__) + "/../../../applications/utils")

from haf_utilities import helper, argument_parser, args_container
from haf_base import haf_base, application

class sql_accounts(haf_base):
  
  def __init__(self, schema_name):
    super().__init__()
    self.app                          = None
    self.schema_name                  = schema_name
    self.create_creator_account_table = ''
    self.get_accounts                 = ''
    self.insert_into_history          = []

  def prepare_sql(self):
    #SQL queries
    self.create_creator_account_table = '''
      CREATE SCHEMA IF NOT EXISTS {};
      CREATE TABLE IF NOT EXISTS {}.creation_history
      (
        block_num INTEGER NOT NULL,
        creator_id INTEGER DEFAULT NULL,
        account_id INTEGER NOT NULL
      );
    '''.format(self.schema_name, self.schema_name)

    self.get_accounts = '''
      SELECT block_num, body
      FROM hive.{}_operations_view o
      JOIN hive.operation_types ot ON o.op_type_id = ot.id
      WHERE ot.name = 'hive::protocol::account_created_operation' AND block_num >= {} and block_num <= {}
    '''

    self.insert_into_history.append( "INSERT INTO {}.creation_history(block_num, creator_id, account_id) SELECT T.block_num, C.id, A.id FROM ( VALUES".format(self.schema_name) )
    self.insert_into_history.append( " ( {}, '{}', '{}' )" )
    self.insert_into_history.append( '''
      ) T(block_num, creator, new_account)
      LEFT JOIN hive.{}_accounts_view C ON T.creator = C.name
      JOIN hive.{}_accounts_view A ON T.new_account = A.name
    '''.format(self.app.app_context, self.app.app_context) )

  def checker(self):
    assert self.app is not None, "an app must be initialized"

  def pre_none_ctx(self):
    helper.info("Creation SQL tables: (PRE-NON-CTX phase)")
    self.checker()

    self.prepare_sql()
    _result = self.app.exec_query(self.create_creator_account_table)

  def pre_is_ctx(self):
    pass

  def pre_always(self):
    pass

  def run(self, low_block, high_block):
    helper.info("processing incoming data: (RUN phase)")
    self.checker()

    _query = self.get_accounts.format(self.app.app_context, low_block, high_block)
    _result = self.app.exec_query_all(_query)

    helper.info("For blocks {}:{} found {} new accounts".format(low_block, high_block, len(_result)))

    _values = []
    for record in _result:
      _op = json.loads(record[1])

      _new_account_name = None
      _creator          = None

      if 'value' in _op:
        _value = _op['value']
        if 'new_account_name' in _value:
          _new_account_name = _value['new_account_name']
          _creator = _value['creator']
          _values.append(self.insert_into_history[1].format(record[0], _creator, _new_account_name))

    helper.execute_complex_query(self.app, _values, self.insert_into_history)

  def post(self): 
    pass

def main():
  _parser = argument_parser()
  _parser.parse()

  _schema_name      = "new_accounts"
  _sql_accounts     = sql_accounts(_schema_name)
  _app              = application(args_container(_parser.get_url(), _parser.get_range_blocks(), _parser.get_massive_threshold()), _schema_name + "_app", _sql_accounts)

  _app.process()

if __name__ == '__main__':
  main()
