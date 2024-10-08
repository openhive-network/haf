-- Compare functions for the hive_data.operation

CREATE OPERATOR = (
    LEFTARG    = hive_data.operation,
    RIGHTARG   = hive_data.operation,
    COMMUTATOR = =,
    NEGATOR    = !=,
    PROCEDURE  = hive_data._operation_eq,
	RESTRICT = eqsel,
    JOIN = eqjoinsel,
	MERGES
);

CREATE OPERATOR != (
    LEFTARG    = hive_data.operation,
    RIGHTARG   = hive_data.operation,
    NEGATOR    = =,
    COMMUTATOR = !=,
    PROCEDURE  = hive_data._operation_ne,
	RESTRICT = neqsel,
    JOIN = neqjoinsel
);

CREATE OPERATOR < (
    LEFTARG    = hive_data.operation,
    RIGHTARG   = hive_data.operation,
    COMMUTATOR = <,
    NEGATOR    = >=,
    PROCEDURE  = hive_data._operation_lt,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR <= (
    LEFTARG    = hive_data.operation,
    RIGHTARG   = hive_data.operation,
    COMMUTATOR = <=,
    NEGATOR    = >,
    PROCEDURE  = hive_data._operation_le,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR > (
    LEFTARG    = hive_data.operation,
    RIGHTARG   = hive_data.operation,
    COMMUTATOR = >,
    NEGATOR    = <=,
    PROCEDURE  = hive_data._operation_gt,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR >= (
    LEFTARG    = hive_data.operation,
    RIGHTARG   = hive_data.operation,
    COMMUTATOR = >=,
    NEGATOR    = <,
    PROCEDURE  = hive_data._operation_ge,
    RESTRICT = contsel,
	JOIN = contjoinsel
);


CREATE OPERATOR CLASS hive.operation_ops
DEFAULT FOR TYPE hive_data.operation USING btree AS
    OPERATOR    1   <  (hive_data.operation, hive_data.operation),
    OPERATOR    2   <= (hive_data.operation, hive_data.operation),
    OPERATOR    3   =  (hive_data.operation, hive_data.operation),
    OPERATOR    4   >= (hive_data.operation, hive_data.operation),
    OPERATOR    5   >  (hive_data.operation, hive_data.operation),
    FUNCTION    1   hive_data._operation_cmp(hive_data.operation, hive_data.operation),
STORAGE hive_data.operation;
