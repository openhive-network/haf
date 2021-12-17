import sys
import logging

from signal import signal, SIGINT, SIGTERM

from collections import deque

from abc import ABC, abstractmethod

from haf_sql import haf_sql, haf_context_switcher
from haf_utilities import range_type, args_container, helper, timer

LOG_LEVEL = logging.INFO
LOG_FORMAT = "%(asctime)-15s - %(name)s - %(levelname)s - %(message)s"
MAIN_LOG_PATH = "haf-base.log"

MODULE_NAME = "HAF-TEMPLATE"
logger = logging.getLogger(MODULE_NAME)
logger.setLevel(LOG_LEVEL)

ch = logging.StreamHandler(sys.stdout)
ch.setLevel(LOG_LEVEL)
ch.setFormatter(logging.Formatter(LOG_FORMAT))

fh = logging.FileHandler(MAIN_LOG_PATH)
fh.setLevel(LOG_LEVEL)
fh.setFormatter(logging.Formatter(LOG_FORMAT))

if not logger.hasHandlers():
  logger.addHandler(ch)
  logger.addHandler(fh)

INTERRUPTED = False

class haf_base(ABC):
  def __init__(self, sql = None):
    super(haf_base, self).__init__()

    self.is_massive     = False

    self.last_block_num = 0

    self.block_ranges   = deque()

    self.sql            = sql

    helper.logger = logger

  #Every application written in python should inherit from `haf_base`. Following abstract methods are called during different stages.

  #Executed once: only when a context doesn't exist. Mainly used when new schema, new tables, new SQL functions must be created
  @abstractmethod
  def pre_none_ctx(self):
    pass

  #Executed once: only when a context exists. It can be used f.e. so as to check data integrity.
  @abstractmethod
  def pre_is_ctx(self):
    pass

  #Executed once: it's always executed after `pre_none_ctx`/`pre_is_ctx`. It doesn't matter if a context exists or doesn't
  @abstractmethod
  def pre_always(self):
    pass

  #Executed many times when a new portion of blocks appears.
  #Parameters from command line: `range-blocks`, `massive-threshold` decide if given context is switched and how many blocks are processed at once
  #Here `low_block`, `high_block` depend on `range-blocks`
  @abstractmethod
  def run(self, low_block, high_block):
    pass

  #Executed many times after processing a current portion of blocks.
  @abstractmethod
  def post(self): 
    pass

  def is_interrupted(self):
    return INTERRUPTED

  def raise_exception(self, source_exception):
    INTERRUPTED = True
    raise source_exception

  def preprocess(self):
    try:
      with timer("TOTAL PREPROCESS[ms]: {}") as tm:
        if self.is_interrupted():
          helper.info("preprocessing has been interrupted")
          return False

        if not self.sql.exec_exists_context():
          self.sql.exec_create_context()

          self.pre_none_ctx()
        else:
          self.pre_is_ctx()

        self.pre_always()
        return True
    except Exception as ex:
      helper.error("`preprocess` method exception: {0}", ex)
      self.raise_exception(ex)

  def get_blocks(self):
    try:
      with timer("TOTAL GET BLOCKS[ms]: {}") as tm:
        if self.is_interrupted():
          helper.info("getting blocks has been interrupted")
          return None, None

        _first_block = 0
        _last_block  = 0

        self.sql.attach_context()
        _range_blocks = self.sql.exec_next_block()

        if _range_blocks is not None and len(_range_blocks) > 0:
          assert len(_range_blocks) == 1

          _record = _range_blocks[0]

          if _record[0] is None or _record[1] is None:
            helper.info("Values in range blocks have NULL")
            return None, None
          else:
            _first_block  = int(_record[0])
            _last_block   = int(_record[1])

          helper.info("first block: {} last block: {}", _first_block, _last_block)
          return _first_block, _last_block
        else:
          helper.info("Range blocks is returned empty")
          return None, None
    except Exception as ex:
      helper.error("`get_blocks` method exception: {0}", ex)
      self.raise_exception(ex)

  def fill_block_ranges(self, first_block, last_block):
    try:
      with timer("TOTAL FILLING BLOCKS[ms]: {}") as tm:
        if self.is_interrupted():
          helper.info("filling block ranges has been interrupted")
          return False

        if first_block == last_block:
          self.block_ranges.append(range_type(first_block, last_block))
          return True

        _last_block = first_block

        while _last_block != last_block:
          _last_block = min(_last_block + helper.args.range_blocks, last_block)
          self.block_ranges.append(range_type(first_block, _last_block))
          first_block = _last_block + 1

        return True
    except Exception as ex:
      helper.error("`fill_block_ranges` method exception: {0}", ex)
      self.raise_exception(ex)

  def work(self):
    try:
      with timer("TOTAL WORK[ms]: {}") as tm:
        if self.is_interrupted():
          helper.info("`work` method has been interrupted")
          return False

        while len(self.block_ranges) > 0:
          if self.is_interrupted():
            helper.info("main loop in `work` method has been interrupted")
            return False

          _item = self.block_ranges.popleft()

          self.run(_item.low, _item.high)

          self.last_block_num = _item.high

          if self.is_massive and self.last_block_num is not None:
            self.sql.exec_context_detached_save_block_num(self.last_block_num)

        return True
    except Exception as ex:
      helper.error("`work` method exception: {0}", ex)
      self.raise_exception(ex)

  def run_impl(self):
    try:
      with timer("TOTAL RUN-IMPL[ms]: {}") as tm:
        if self.is_interrupted():
          helper.info("`run_impl` method has been interrupted")
          return False

        _first_block, _last_block = self.get_blocks()
        if _first_block is None:
          return True

        self.is_massive = _last_block - _first_block + 1 > helper.args.massive_threshold
        helper.info("an application is in '{}' mode", "massive" if self.is_massive else "live")

        if self.is_massive:
          self.fill_block_ranges(_first_block, _last_block)

          with haf_context_switcher(self.sql, self.last_block_num):
            self.work()

        else:
          self.fill_block_ranges(_first_block, _first_block)
          self.work()

        return True
    except Exception as ex:
      helper.error("`run_impl` method exception: {0}", ex)
      self.raise_exception(ex)

  def postprocess(self):
    try:
      with timer("TOTAL POSTPROCESS[ms]: {}") as tm:
        if self.is_interrupted():
          helper.info("postprocessing has been interrupted")
          return False

        self.post()

        return True
    except Exception as ex:
      helper.error("`postprocess` method exception: {0}", ex)
      self.raise_exception(ex)

  def total_run(self):
    with timer("TOTAL RUN[ms]: {}") as tm:
      try:
        _result = self.preprocess()
        if not _result:
          return False

        while True:
          if not self.run_impl():
            break

        _result = self.postprocess()
        if not _result:
          return False
      except Exception as ex:
        helper.error("`run` method exception: {0}", ex)
        self.raise_exception(ex)

def shutdown_properly(signal, frame):
  helper.info("Closing. Wait...")

  global INTERRUPTED
  INTERRUPTED = True

  helper.info("Interrupted...")

old_sig_int_handler = None
old_sig_term_handler = None

def set_handlers():
  global old_sig_int_handler
  global old_sig_term_handler
  old_sig_int_handler = signal(SIGINT, shutdown_properly)
  old_sig_term_handler = signal(SIGTERM, shutdown_properly)

def restore_handlers():
  signal(SIGINT, old_sig_int_handler)
  signal(SIGTERM, old_sig_term_handler)

class application:
  def __init__(self, args, app_context, sql_app):
    helper.args       = args

    self.app_context  = app_context
    self.sql_app      = sql_app
    self.sql_app.sql  = haf_sql(self.app_context, helper.args.url)
    self.sql_app.app  = self

  def exec_query(self, query, **kwargs):
    assert self.sql_app is not None
    self.sql_app.sql.exec_query(query, **kwargs)

  def exec_query_all(self, query, **kwargs):
    assert self.sql_app is not None
    return self.sql_app.sql.exec_query_all(query, **kwargs)

  def exec_query_one(self, query, **kwargs):
    assert self.sql_app is not None
    return self.sql_app.sql.exec_query_one(query, **kwargs)

  def process(self):
    try:
      with timer("TOTAL APPLICATION TIME[ms]: {}") as tm:

        set_handlers()

        result = self.sql_app.total_run()

        restore_handlers()

    except Exception as ex:
      helper.error("`process` method exception: {0}", ex)
      exit(1)
