
CREATE SCHEMA mmm;




SELECT hive.app_create_context('mmm');

SELECT hive.app_state_provider_import('KEYAUTH', 'mmm');

CALL hive.appproc_context_detach('mmm');







CREATE OR REPLACE FUNCTION mmm.main_test(
    IN _appContext VARCHAR,
    IN _from INT,
    IN _to INT,
    IN _step INT
)
RETURNS void
LANGUAGE 'plpgsql'

AS
$$
DECLARE
_last_block INT ;
BEGIN


  FOR b IN _from .. _to BY _step LOOP
    _last_block := b + _step - 1;

    IF _last_block > _to THEN --- in case the _step is larger than range length
      _last_block := _to;
    END IF;

    RAISE NOTICE 'Attempting to process a block range: <%, %>', b, _last_block;

    PERFORM hive.app_state_providers_update(b, _last_block, _appContext);

    RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;

  END LOOP;



 RAISE NOTICE 'Leaving massive processing of block range: <%, %>...', _from, _to;
END
$$;


