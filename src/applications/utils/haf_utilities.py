from time import perf_counter
import argparse

# convert special chars into their octal formats recognized by sql
SPECIAL_CHARS = {
    "\x00" : " ", # nul char cannot be stored in string column (ABW: if we ever find the need to store nul chars we'll need bytea, not text)
    "\r" : "\\015",
    "\n" : "\\012",
    "\v" : "\\013",
    "\f" : "\\014",
    "\\" : "\\134",
    "'" : "\\047",
    "%" : "\\045",
    "_" : "\\137",
    ":" : "\\072"
}

class range_type:
  def __init__(self, low, high):
    self.low  = low
    self.high = high

class args_container:
  def __init__(self, url = "", range_blocks = 1000, massive_threshold = 1):
    self.url                = url
    self.range_blocks       = range_blocks
    self.massive_threshold  = massive_threshold

class helper:
  args    = None
  logger  = None

  @staticmethod
  def info(msg, *args):
    if helper.logger is not None:
      helper.logger.info(msg.format(*args))

  @staticmethod
  def error(msg, *args):
    if helper.logger is not None:
      helper.logger.error(msg.format(*args))

  @staticmethod
  def display_query(query):
    if len(query) > 100:
      helper.info("{}...", query[0:100])
    else:
      helper.info("{}", query)

  @staticmethod
  def execute_complex_query(app, values, q_parts):
    if len(values) == 0:
      return

    cnt = 0
    _total_query = q_parts[0]

    for item in values:
      _total_query += ( "," if cnt else "" ) + item
      cnt += 1

    _total_query += q_parts[2]

    _result = app.exec_query(_total_query)

  @staticmethod
  def escape_characters(text):
      """ Escape special charactes """
      assert isinstance(text, str), "Expected string got: {}".format(type(text))
      if len(text.strip()) == 0:
          return "'" + text + "'"

      ret = "E'"

      for ch in text:
          if ch in SPECIAL_CHARS:
              dw = SPECIAL_CHARS[ch]
              ret = ret + dw
          else:
              ordinal = ord(ch)
              if ordinal <= 0x80 and ch.isprintable():
                  ret = ret + ch
              else:
                  hexstr = hex(ordinal)[2:]
                  i = len(hexstr)
                  max = 4
                  escaped_value = '\\u'
                  if i > max:
                      max = 8
                      escaped_value = '\\U'
                  while i < max:
                      escaped_value += '0'
                      i += 1
                  escaped_value += hexstr
                  ret = ret + escaped_value

      ret = ret + "'"
      return ret

class timer:
  def __init__(self, message):
    self.message  = message
    self.start    = None

  def __enter__(self):
    self.start    = perf_counter()
    return self

  def __exit__(self, *args, **kwargs):
    self.time = int((perf_counter() - self.start)*1000)
    helper.info(self.message.format(self.time))

class argument_parser:
  def __init__(self):
    self.args   = None
    self.parser = argparse.ArgumentParser()
    self.add_basic_arguments()

  def add_basic_arguments(self):
    #./haf_base.py -p postgresql://LOGIN:PASSWORD@127.0.0.1:5432/DB_NAME --range-blocks 40000
    self.parser.add_argument("--url", type = str, help = "postgres connection string for AH database")
    self.parser.add_argument("--range-blocks", type = int, default = 1000, help = "Number of blocks processed at once")
    self.parser.add_argument("--massive-threshold", type = int, default = 1, help = "Number of blocks GREATER THAN a massive threshold activates a massive mode")

  def parse(self):
    self.args = self.parser.parse_args()

  def get_url(self):
    return self.args.url

  def get_range_blocks(self):
    return self.args.range_blocks

  def get_massive_threshold(self):
    return self.args.massive_threshold