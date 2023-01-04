-- Compare functions for the hive.operation

CREATE OPERATOR = (
    LEFTARG    = hive.operation,
    RIGHTARG   = hive.operation,
    COMMUTATOR = =,
    NEGATOR    = !=,
    PROCEDURE  = hive._operation_eq
);

CREATE OPERATOR != (
    LEFTARG    = hive.operation,
    RIGHTARG   = hive.operation,
    NEGATOR    = =,
    COMMUTATOR = !=,
    PROCEDURE  = hive._operation_ne
);