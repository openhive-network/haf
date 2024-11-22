-- Compare functions for the hafd.operation

CREATE OPERATOR = (
    LEFTARG    = hafd.operation,
    RIGHTARG   = hafd.operation,
    COMMUTATOR = =,
    NEGATOR    = !=,
    PROCEDURE  = hafd._operation_eq,
	RESTRICT = eqsel,
    JOIN = eqjoinsel,
	MERGES
);

CREATE OPERATOR != (
    LEFTARG    = hafd.operation,
    RIGHTARG   = hafd.operation,
    NEGATOR    = =,
    COMMUTATOR = !=,
    PROCEDURE  = hafd._operation_ne,
	RESTRICT = neqsel,
    JOIN = neqjoinsel
);

CREATE OPERATOR < (
    LEFTARG    = hafd.operation,
    RIGHTARG   = hafd.operation,
    COMMUTATOR = <,
    NEGATOR    = >=,
    PROCEDURE  = hafd._operation_lt,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR <= (
    LEFTARG    = hafd.operation,
    RIGHTARG   = hafd.operation,
    COMMUTATOR = <=,
    NEGATOR    = >,
    PROCEDURE  = hafd._operation_le,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR > (
    LEFTARG    = hafd.operation,
    RIGHTARG   = hafd.operation,
    COMMUTATOR = >,
    NEGATOR    = <=,
    PROCEDURE  = hafd._operation_gt,
    RESTRICT = contsel,
	JOIN = contjoinsel
);

CREATE OPERATOR >= (
    LEFTARG    = hafd.operation,
    RIGHTARG   = hafd.operation,
    COMMUTATOR = >=,
    NEGATOR    = <,
    PROCEDURE  = hafd._operation_ge,
    RESTRICT = contsel,
	JOIN = contjoinsel
);


CREATE OPERATOR CLASS hafd.operation_ops
DEFAULT FOR TYPE hafd.operation USING btree AS
    OPERATOR    1   <  (hafd.operation, hafd.operation),
    OPERATOR    2   <= (hafd.operation, hafd.operation),
    OPERATOR    3   =  (hafd.operation, hafd.operation),
    OPERATOR    4   >= (hafd.operation, hafd.operation),
    OPERATOR    5   >  (hafd.operation, hafd.operation),
    FUNCTION    1   hafd._operation_cmp(hafd.operation, hafd.operation),
STORAGE hafd.operation;
