-- Actual hive_data.operation type implementation

CREATE TYPE hive_data.operation(
    INPUT = hive_data._operation_in -- JSON string -> hive_data.operation
  , OUTPUT = hive_data._operation_out -- hive_data.operation -> JSON string

  , RECEIVE = hive_data._operation_bin_in_internal -- internal -> hive_data.operation
  , SEND = hive_data._operation_bin_out -- hive_data.operation -> bytea

  , INTERNALLENGTH = VARIABLE
  --- According to documentation: https://www.postgresql.org/docs/current/storage-toast.html#STORAGE-TOAST-ONDISK
  --- we want to held this data embedded inside table row, instead of pushing to external storage.
  , STORAGE = MAIN
);
