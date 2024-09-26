--convert text parameters that accept timestamp and int into blocks_range
CREATE OR REPLACE FUNCTION hive.convert_to_blocks_range(_from TEXT, _to TEXT)
    RETURNS hive.blocks_range
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
DECLARE
    __from_block INT := NULL;
    __to_block INT := NULL;
    __converted_timestamp1 TIMESTAMP := NULL;
    __converted_timestamp2 TIMESTAMP := NULL;
BEGIN
  -- Try to convert _from to integer
  BEGIN
    __from_block := _from::INT;
  EXCEPTION
    WHEN OTHERS THEN
    -- Do nothing, move to the next block
  END;

  -- Try to convert _from to timestamp if it's not an integer
  IF __from_block IS NULL THEN
    BEGIN
      __converted_timestamp1 := _from::TIMESTAMP;
    EXCEPTION
    -- if it's not a timestamp either - raise exception
      WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid format: %',_from;
    END;
  
    __from_block := (SELECT num FROM hive.blocks_view bv WHERE bv.created_at >= __converted_timestamp1 ORDER BY created_at ASC LIMIT 1);  
  END IF;

  IF __converted_timestamp1 IS NOT NULL AND __from_block IS NULL THEN
    RAISE EXCEPTION 'Block-num was not found for provided timestamp (%)', __converted_timestamp1;
  END IF;

  -- Try to convert _to to integer
  BEGIN
    __to_block := _to::INT;
  EXCEPTION
    WHEN OTHERS THEN
        -- Do nothing, move to the next block
  END;

  -- Try to convert _to to timestamp if it's not an integer
  IF __to_block IS NULL THEN
    BEGIN
      __converted_timestamp2 := _to::TIMESTAMP;
    EXCEPTION
    -- if it's not a timestamp either - raise exception
      WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid format: %',_to;
    END;

    __to_block := (SELECT num FROM hive.blocks_view bv WHERE bv.created_at <= __converted_timestamp2 ORDER BY created_at DESC LIMIT 1);
  END IF;

  IF __converted_timestamp2 IS NOT NULL AND __to_block IS NULL THEN
    RAISE EXCEPTION 'Block-num was not found for provided timestamp (%)', __converted_timestamp2;
  END IF;

  IF __converted_timestamp2 < __converted_timestamp1  THEN
    RAISE EXCEPTION 'The starting timestamp (%) must be earlier or equal to the ending timestamp (%).', __converted_timestamp1, __converted_timestamp2;
  END IF;

  IF __to_block < __from_block THEN

    IF __converted_timestamp1 IS NOT NULL AND __converted_timestamp2 IS NOT NULL THEN
      RAISE EXCEPTION 'The starting block (%) for timestamp (%) must be less than or equal to the ending block (%) for timestamp (%).', __from_block, __converted_timestamp1, __to_block, __converted_timestamp2;
    END IF;

    RAISE EXCEPTION 'The starting block (%) must be less than or equal to the ending block (%).', __from_block, __to_block;
  
  END IF;
  
  -- Return both results
  RETURN (__from_block,__to_block)::hive.blocks_range;
END
$BODY$
;

CREATE OR REPLACE FUNCTION hive.convert_to_block_num(_block TEXT)
    RETURNS INT
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN				
  RETURN last_block FROM hive.convert_to_blocks_range(NULL, _block);
END;
$BODY$
;