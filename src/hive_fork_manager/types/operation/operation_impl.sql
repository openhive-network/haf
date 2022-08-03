-- Actual hive.operation type implementation

CREATE TYPE hive.operation(
    INPUT = hive._operation_in -- JSON string -> hive.operation
  , OUTPUT = hive._operation_out -- hive.operation -> JSON string

  , RECEIVE = hive._operation_bin_in_internal -- internal -> hive.operation
  , SEND = hive._operation_bin_out -- hive.operation -> bytea

  , INTERNALLENGTH = VARIABLE
  , STORAGE = extended
);
