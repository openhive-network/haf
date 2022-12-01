-- Compare functions for the hive.operation

CREATE OPERATOR = (
    LEFTARG    = hive.operation,
    RIGHTARG   = hive.operation,
    COMMUTATOR = =,
    NEGATOR    = !=,
    PROCEDURE  = hive._operation_eq,
	RESTRICT = eqsel,
    JOIN = eqjoinsel,
	MERGES
);

CREATE OPERATOR != (
    LEFTARG    = hive.operation,
    RIGHTARG   = hive.operation,
    NEGATOR    = =,
    COMMUTATOR = !=,
    PROCEDURE  = hive._operation_ne,
	RESTRICT = neqsel,
    JOIN = neqjoinsel
);

CREATE OPERATOR < (
    LEFTARG    = hive.operation,
    RIGHTARG   = hive.operation,
    COMMUTATOR = <,
    NEGATOR    = >=,
    PROCEDURE  = hive._operation_lt,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR <= (
    LEFTARG    = hive.operation,
    RIGHTARG   = hive.operation,
    COMMUTATOR = <=,
    NEGATOR    = >,
    PROCEDURE  = hive._operation_le,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR > (
    LEFTARG    = hive.operation,
    RIGHTARG   = hive.operation,
    COMMUTATOR = >,
    NEGATOR    = <=,
    PROCEDURE  = hive._operation_gt,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR >= (
    LEFTARG    = hive.operation,
    RIGHTARG   = hive.operation,
    COMMUTATOR = >=,
    NEGATOR    = <,
    PROCEDURE  = hive._operation_ge,
    RESTRICT = contsel,
	JOIN = contjoinsel
);


CREATE OPERATOR CLASS hive.operation_ops
DEFAULT FOR TYPE hive.operation USING btree AS
    OPERATOR    1   <  (hive.operation, hive.operation),
    OPERATOR    2   <= (hive.operation, hive.operation),
    OPERATOR    3   =  (hive.operation, hive.operation),
    OPERATOR    4   >= (hive.operation, hive.operation),
    OPERATOR    5   >  (hive.operation, hive.operation),
    FUNCTION    1   hive._operation_cmp(hive.operation, hive.operation),
STORAGE hive.operation;
