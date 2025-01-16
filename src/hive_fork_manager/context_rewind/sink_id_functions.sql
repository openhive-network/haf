CREATE OR REPLACE FUNCTION hive.unreachable_event_id()
    RETURNS BIGINT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN 9223372036854775807; -- MAX BIGINT
END
$$;

CREATE OR REPLACE FUNCTION hive.max_block_num()
    RETURNS BIGINT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN 2147483647; -- MAX INTEGER
END
$$;

CREATE OR REPLACE FUNCTION hive.max_fork_id()
    RETURNS BIGINT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN 9223372036854775807; -- MAX BIGINT
END
$$;

