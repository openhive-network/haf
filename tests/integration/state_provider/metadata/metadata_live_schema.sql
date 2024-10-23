CREATE SCHEMA metadata_live;

CREATE OR REPLACE PROCEDURE metadata_live.main(
	IN _appcontext character varying,
	IN _from integer,
	IN _to integer,
	IN _step integer)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
	_last_block INT;
BEGIN
  RAISE NOTICE 'Entering massive processing of block range: <%, %>...', _from, _to;
  RAISE NOTICE 'Detaching HAF application context...';
  PERFORM hive.app_context_detach(_appContext);


  FOR b IN _from .. _to BY _step LOOP
    _last_block := b + _step - 1;

    IF _last_block > _to THEN 
      _last_block := _to;
    END IF;

    RAISE NOTICE 'Attempting to process a block range: <%, %>', b, _last_block;

    PERFORM hive.app_state_providers_update(b, _last_block, _appContext);
 
    RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;

  END LOOP;

 RAISE NOTICE 'Leaving massive processing of block range: <%, %>...', _from, _to;
END
$BODY$;

CREATE TABLE IF NOT EXISTS metadata_live.jsons (
  account text,
  json_metadata text DEFAULT '',
  posting_json_metadata text DEFAULT '',

CONSTRAINT pk_json_metadata_comparison PRIMARY KEY (account)
);

CREATE TABLE IF NOT EXISTS metadata_live.differing_accounts (
  account TEXT
);

CREATE OR REPLACE FUNCTION metadata_live.current_state(_account text)
RETURNS SETOF metadata_live.jsons
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN QUERY
  SELECT
    _account,
    m.json_metadata,
    m.posting_json_metadata
  FROM
    hafd.metadata_live_metadata m JOIN hive.accounts_view av ON m.account_id = av.id
  WHERE av.name = _account;
END
$$;

CREATE OR REPLACE FUNCTION metadata_live.dump_current_account_stats(account_data jsonb)
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$$
BEGIN
  INSERT INTO metadata_live.jsons
    SELECT 
        account_data->>'name' as account,
        account_data->>'json_metadata' as json_metadata,
        account_data->>'posting_json_metadata' as posting_json_metadata;
END
$$;

CREATE OR REPLACE FUNCTION metadata_live.compare_accounts()
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$$
BEGIN
  WITH jsons AS (
    SELECT *
    FROM metadata_live.jsons
  )
  INSERT INTO metadata_live.differing_accounts
    SELECT jsons.account
    FROM jsons
    JOIN metadata_live.current_state(jsons.account) AS current_stats ON current_stats.account = jsons.account
    WHERE 
        jsons.json_metadata != current_stats.json_metadata OR 
        jsons.posting_json_metadata != current_stats.posting_json_metadata;
END
$$;
