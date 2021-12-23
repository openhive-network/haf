#Every application written in python should be attached to HAF by callbacks. Following callbacks are called during different stages.

class callback_handler_example:

  #Executed once: only when a context doesn't exist. Mainly used when new schema, new tables, new SQL functions must be created
  def pre_none_ctx(self):
    pass

  #Executed once: only when a context exists. It can be used f.e. so as to check data integrity.
  def pre_is_ctx(self):
    pass

  #Executed once: it's always executed after `pre_none_ctx`/`pre_is_ctx`. It doesn't matter if a context exists or doesn't
  def pre_always(self):
    pass

  #Executed many times when a new portion of blocks appears.
  #For massive sync:  high_block - low_block == range-blocks( a parameter from a command line )
  #For live sync:     high_block - low_block == 1
  def run(self, low_block, high_block):
    pass

  #Executed many times after processing a current portion of blocks.
  def post(self):
    pass
