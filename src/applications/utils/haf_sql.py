from haf_utilities import helper, timer

from adapter import Db

class haf_query:
  def __init__(self, application_context):

    self.application_context              = application_context

    self.create_context                   = "SELECT hive.app_create_context('{}');".format( self.application_context )
    self.detach_context                   = "SELECT hive.app_context_detach('{}');".format( self.application_context )
    self.attach_context                   = "SELECT hive.app_context_attach('{}', {});"
    self.exists_context                   = "SELECT * FROM hive.app_context_exists('{}');".format( self.application_context )

    self.context_is_attached              = "SELECT * FROM hive.app_context_is_attached('{}')".format( self.application_context )
    self.context_detached_save_block_num  = "SELECT hive.app_context_detached_save_block_num('{}', {})"
    self.context_detached_get_block_num   = "SELECT * FROM hive.app_context_detached_get_block_num('{}')".format( self.application_context )
    
    self.context_current_block_num        = "SELECT current_block_num FROM hive.contexts WHERE NAME = '{}'".format( self.application_context )
    
    self.next_block                       = "SELECT * FROM hive.app_next_block('{}');".format( self.application_context )

class haf_sql:
  def __init__(self, application_context):
    helper.info("Initialization of a new database connection...")
    self.db         = Db(helper.args.url, "root db creation")
    helper.info("The database has been connected...")

    self.text_query = haf_query(application_context)

  def exec_query(self, query, **kwargs):
    with timer("query time[ms]: {}") as tm:
      helper.display_query(query, **kwargs)

      assert self.db is not None, "self.db is not None"
      self.db.query_no_return(query)

  def exec_query_all(self, query, **kwargs):
    with timer("query time[ms]: {}") as tm:
      helper.display_query(query)

      assert self.db is not None, "self.db is not None"
      return self.db.query_all(query, **kwargs)

  def exec_query_one(self, query, **kwargs):
    with timer("query time[ms]: {}") as tm:
      helper.display_query(query)

      assert self.db is not None, "self.db is not None"
      return self.db.query_one(query, **kwargs)

  def exec_create_context(self):
    self.exec_query(self.text_query.create_context)

  def exec_detach_context_impl(self):
    self.exec_query(self.text_query.detach_context)

  def exec_attach_context_impl(self, block_num):
    _query = self.text_query.attach_context.format(self.text_query.application_context, block_num)
    self.exec_query(_query)

  def exec_exists_context(self):
    return self.exec_query_one(self.text_query.exists_context)

  def exec_context_is_attached(self):
    return self.exec_query_one(self.text_query.context_is_attached)

  def exec_context_detached_save_block_num(self, block_num):
    _query = self.text_query.context_detached_save_block_num.format(self.text_query.application_context, block_num)
    self.exec_query(_query)

  def exec_context_detached_get_block_num(self):
    return self.exec_query_one(self.text_query.context_detached_get_block_num)

  def exec_context_current_block_num(self):
    return self.exec_query_one(self.text_query.context_current_block_num)

  def exec_next_block(self):
    return self.exec_query_all(self.text_query.next_block)

  def get_last_block_num(self):
    _result = self.exec_context_detached_get_block_num()
    if _result is None:
      _result = self.exec_context_current_block_num()
    return _result

  def switch_context_internal(self, force_attach, last_block = 0):
    _is_attached = self.exec_context_is_attached()

    if _is_attached == force_attach:
      helper.info("Context is already {}", "attached" if _is_attached else "detached")
      return

    if force_attach:
      if last_block == 0:
        last_block = self.get_last_block_num()

      _attach_context_query = self.exec_attach_context_impl(last_block)
    else:
      self.exec_detach_context_impl()

  def attach_context(self, last_block = 0):
    self.switch_context_internal(True, last_block)

  def detach_context(self):
    self.switch_context_internal(False)

class haf_context_switcher:
  def __init__(self, sql, last_block_num):
    self.sql            = sql
    self.last_block_num = last_block_num

  def __enter__(self):
    assert self.sql is not None, "a sql query manager must be initialized"
    self.sql.detach_context()
    return self

  def __exit__(self, *args, **kwargs):
    assert self.sql is not None, "a sql query manager must be initialized"
    self.sql.attach_context(self.last_block_num if (self.last_block_num is not None) else 0)
