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

CREATE OR REPLACE FUNCTION hive.block_sink_num()
    RETURNS INT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN 0;
END
$$;

