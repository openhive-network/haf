#!/usr/bin/python3

#Storing all changes of account creation fee

import os
import json
import re
import sys

sys.path.append(os.path.dirname(__file__) + "/../../../applications/utils")

from haf_utilities import helper, range_type, argument_parser, args_container
from haf_base import haf_base, application

from haf_account_creation_fee_follower import sql_account_creation_fee_follower

from concurrent.futures import ThreadPoolExecutor, as_completed

class sql_account_creation_fee_follower_threads(sql_account_creation_fee_follower):

  def __init__(self, threads, schema_name):
    super().__init__(schema_name)
    self.threads  = threads

  def pre_none_ctx(self):
    super().pre_none_ctx()

  def pre_is_ctx(self):
    super().pre_is_ctx()

  def pre_always(self):
    super().pre_always()

  def prepare_ranges(self, low_value, high_value, threads):
    assert threads > 0 and threads <= 64, "threads > 0 and threads <= 64"

    if threads == 1:
      return [ range_type(low_value, high_value) ]

    #It's better to send small amount of data in only 1 thread. More threads introduce unnecessary complexity.
    #Beside, if (high_value - low_value) < threads, it's impossible to spread data amongst threads in reasonable way.
    _thread_threshold = 500
    if high_value - low_value + 1 <= _thread_threshold:
      return [ range_type(low_value, high_value) ]

    _ranges = []
    _size = int(( high_value - low_value + 1 ) / threads)

    for i in range(threads):
      if i == 0:
        _ranges.append(range_type(low_value, low_value + _size))
      else:
        _low = _ranges[i - 1].high + 1
        _ranges.append(range_type(_low, _low + _size))

    assert len(_ranges) > 0
    _ranges[len(_ranges) - 1].high = high_value

    return _ranges

  def run(self, low_block, high_block):
    helper.info("processing incoming data: (RUN phase)")
    self.checker()

    _ranges = self.prepare_ranges(low_block, high_block, self.threads)

    _futures = []
    with ThreadPoolExecutor(max_workers=len(_ranges)) as executor:
      for range in _ranges:
        helper.info("new thread created for a range: {}:{}", range.low, range.high)
        _futures.append(executor.submit(super().process_blocks, range.low, range.high))

    for future in as_completed(_futures):
      future.result()

  def post(self): 
    super().post()

class argument_parser_ex(argument_parser):
  def __init__(self):
    super().__init__()
    self.parser.add_argument("--threads", type = int, default = 2, help = "Number of threads used for processing")

  def get_threads(self):
    return self.args.threads

def main():
  _parser = argument_parser_ex()
  _parser.parse()

  _schema_name = "fee_follower_threads"
  _sql_account_creation_fee_follower_threads  = sql_account_creation_fee_follower_threads(_parser.get_threads(), _schema_name)
  _app                                        = application(args_container(_parser.get_url(), _parser.get_range_blocks(), _parser.get_massive_threshold()), _schema_name + "_app", _sql_account_creation_fee_follower_threads)

  _app.process()

if __name__ == '__main__':
  main()
