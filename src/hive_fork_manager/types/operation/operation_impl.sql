-- Actual hafd.operation type implementation

CREATE TYPE hafd.operation(
    INPUT = hafd._operation_in -- JSON string -> hafd.operation
  , OUTPUT = hafd._operation_out -- hafd.operation -> JSON string

  , RECEIVE = hafd._operation_bin_in_internal -- internal -> hafd.operation
  , SEND = hafd._operation_bin_out -- hafd.operation -> bytea

  , INTERNALLENGTH = VARIABLE
  --- According to documentation: https://www.postgresql.org/docs/current/storage-toast.html#STORAGE-TOAST-ONDISK
  --- we want to held this data embedded inside table row, instead of pushing to external storage.
  , STORAGE = MAIN
);
