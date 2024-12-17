CREATE SCHEMA keyauth_live;

CREATE OR REPLACE PROCEDURE keyauth_live.main(
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
CREATE TABLE IF NOT EXISTS keyauth_live.keys (
  account TEXT,

  owner_key JSONB DEFAULT '[]',
  owner_acc JSONB DEFAULT '[]',
  owner_threshold INT DEFAULT 1,
  posting_key JSONB DEFAULT '[]',
  posting_acc JSONB DEFAULT '[]',
  posting_threshold INT DEFAULT 1,

  active_key JSONB DEFAULT '[]',
  active_acc JSONB DEFAULT '[]',
  active_threshold INT DEFAULT 1,

  memo TEXT DEFAULT '',


CONSTRAINT pk_keyauth_comparison PRIMARY KEY (account)
);
    
CREATE TABLE IF NOT EXISTS keyauth_live.differing_accounts (
  account TEXT
);

CREATE OR REPLACE FUNCTION keyauth_live.current_state(_account text)
RETURNS SETOF keyauth_live.keys -- noqa: LT01
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  -- temp is that has threshold 0 without using an operation to set it
  _account_id INT := (SELECT id FROM hive.accounts_view WHERE name = _account);
  _default_threshold INT := 1;
BEGIN
  RETURN QUERY 
  SELECT
  _account,
  COALESCE(key_subquery.owner_key,'[]'),
  COALESCE(acc_subquery.owner_acc,'[]'),
  COALESCE(weight_threshold_subquery.owner_threshold, _default_threshold),

  COALESCE(key_subquery.posting_key,'[]'),
  COALESCE(acc_subquery.posting_acc,'[]'),
  COALESCE(weight_threshold_subquery.posting_threshold, _default_threshold),

  COALESCE(key_subquery.active_key,'[]'),
  COALESCE(acc_subquery.active_acc,'[]'),
  COALESCE(weight_threshold_subquery.active_threshold, _default_threshold),

  COALESCE(key_subquery.memo,'')
FROM
  (
    SELECT
      MAX(CASE WHEN key_kind = 'OWNER' THEN weight_threshold::INT END)::INT AS owner_threshold,
      MAX(CASE WHEN key_kind = 'POSTING' THEN weight_threshold::INT END)::INT AS posting_threshold,
      MAX(CASE WHEN key_kind = 'ACTIVE' THEN weight_threshold::INT END::INT) AS active_threshold
    FROM (
      SELECT
        a.key_kind,
        a.weight_threshold
      FROM hafd.keyauth_live_weight_threshold a
      WHERE a.account_id = _account_id
    ) AS key_agg_subquery
  ) AS weight_threshold_subquery,
  (
    SELECT
      MAX(CASE WHEN key_kind = 'OWNER' THEN key_agg::TEXT END)::JSONB AS owner_key,
      MAX(CASE WHEN key_kind = 'POSTING' THEN key_agg::TEXT END)::JSONB AS posting_key,
      MAX(CASE WHEN key_kind = 'ACTIVE' THEN key_agg::TEXT END)::JSONB AS active_key,
      MAX(CASE WHEN key_kind = 'MEMO' THEN (key_agg::JSONB -> 0 ->> 0)::TEXT END)::TEXT AS memo
    FROM (
      WITH selected AS 
      (
        SELECT
          a.key_kind,
          jsonb_build_array(
            hive.public_key_to_string(c.key),
            a.w
          ) AS key_string
        FROM hafd.keyauth_live_keyauth_a a
        JOIN hafd.keyauth_live_keyauth_k c ON a.key_serial_id = c.key_id
        WHERE a.account_id = _account_id AND a.key_kind != 'WITNESS_SIGNING'
        ORDER BY key_string
      )
      SELECT 
        key_kind,
        jsonb_agg(key_string) AS key_agg
      FROM selected 
      GROUP BY key_kind
    ) AS key_agg_subquery
  ) AS key_subquery,
  (
    SELECT
      MAX(CASE WHEN key_kind = 'OWNER' THEN acc_agg::TEXT END)::JSONB AS owner_acc,
      MAX(CASE WHEN key_kind = 'POSTING' THEN acc_agg::TEXT END)::JSONB AS posting_acc,
      MAX(CASE WHEN key_kind = 'ACTIVE' THEN acc_agg::TEXT END)::JSONB AS active_acc
    FROM (
      WITH selected AS 
      (
        SELECT
          a.key_kind,
          jsonb_build_array(
            c.name,
            a.w
          ) AS name_array
        FROM hafd.keyauth_live_accountauth_a a
        JOIN hive.accounts_view c ON a.account_auth_id = c.id
        WHERE a.account_id = _account_id
        ORDER BY c.name
      )
      SELECT 
        key_kind,
        jsonb_agg(name_array) as acc_agg
      FROM selected 
      GROUP BY key_kind
    ) AS acc_agg_subquery
  ) AS acc_subquery;

END
$$;

CREATE OR REPLACE FUNCTION keyauth_live.compare(_account text)
RETURNS SETOF keyauth_live.keys -- noqa: LT01
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN QUERY 
SELECT * FROM keyauth_live.keys a WHERE a.account =_account 
UNION ALL
SELECT * FROM keyauth_live.current_state(_account);


END 
$$;

CREATE OR REPLACE FUNCTION keyauth_live.dump_current_account_stats(account_data jsonb)
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$$
BEGIN
INSERT INTO keyauth_live.keys 
 SELECT 
    (account_data->>'name')::TEXT,
    COALESCE((account_data->'owner'->'key_auths'),'[]'),
    COALESCE((account_data->'owner'->'account_auths'),'[]'),
    COALESCE((account_data->'owner'->>'weight_threshold')::INT, 1),

    COALESCE((account_data->'posting'->'key_auths'),'[]'),
    COALESCE((account_data->'posting'->'account_auths'),'[]'),
    COALESCE((account_data->'posting'->>'weight_threshold')::INT, 1),

    COALESCE((account_data->'active'->'key_auths'),'[]'),
    COALESCE((account_data->'active'->'account_auths'),'[]'),
    COALESCE((account_data->'active'->>'weight_threshold')::INT, 1),

	  account_data->>'memo_key';
END
$$;

CREATE OR REPLACE FUNCTION keyauth_live.compare_keys(_hived_keys JSONB, _state_provider_keys JSONB)
RETURNS BOOLEAN
LANGUAGE 'plpgsql'
VOLATILE
AS
$$
BEGIN
RETURN (
  WITH json1 AS (
      SELECT jsonb_array_elements(SUB.arr) AS element
      FROM (
          SELECT _hived_keys::jsonb AS arr
      ) AS SUB
  ),
  json2 AS (
      SELECT jsonb_array_elements(SUB.arr) AS element
      FROM (
          SELECT _state_provider_keys::jsonb AS arr
      ) AS SUB
  )
  SELECT NOT EXISTS (
      SELECT 1
      FROM (
          SELECT element FROM json1
          EXCEPT
          SELECT element FROM json2
      ) AS diff1
  )
  AND NOT EXISTS (
      SELECT 1
      FROM (
          SELECT element FROM json2
          EXCEPT
          SELECT element FROM json1
      ) AS diff2
  ) AS arrays_are_equal
);
END
$$;

CREATE OR REPLACE FUNCTION keyauth_live.compare_accounts()
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$$
BEGIN
WITH account_balances AS (
  SELECT *
  FROM keyauth_live.keys
)
INSERT INTO keyauth_live.differing_accounts
SELECT account_balances.account
FROM account_balances
JOIN keyauth_live.current_state(account_balances.account) AS _current_account_stats
ON _current_account_stats.account = account_balances.account
WHERE 
  account_balances.memo != _current_account_stats.memo

  OR NOT keyauth_live.compare_keys(account_balances.owner_key, _current_account_stats.owner_key)
  OR NOT keyauth_live.compare_keys(account_balances.active_key, _current_account_stats.active_key)
  OR NOT keyauth_live.compare_keys(account_balances.posting_key, _current_account_stats.posting_key)
  OR NOT keyauth_live.compare_keys(account_balances.owner_acc, _current_account_stats.owner_acc)
  OR NOT keyauth_live.compare_keys(account_balances.active_acc, _current_account_stats.active_acc)
  OR NOT keyauth_live.compare_keys(account_balances.posting_acc, _current_account_stats.posting_acc)

  OR account_balances.owner_threshold != _current_account_stats.owner_threshold
  OR account_balances.posting_threshold != _current_account_stats.posting_threshold
  OR account_balances.active_threshold != _current_account_stats.active_threshold;

END
$$;
