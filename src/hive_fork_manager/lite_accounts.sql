CREATE SCHEMA IF NOT EXISTS la_app;

CREATE TABLE IF NOT EXISTS la_app.accounts (
    id SERIAL NOT NULL
  , namespace TEXT NOT NULL
  , name TEXT NOT NULL
  , owner_key TEXT NOT NULL

  , CONSTRAINT pk_la_app_accounts PRIMARY KEY( id )
  , CONSTRAINT la_app_accounts_uq1 UNIQUE( namespace, name )
);

CREATE TABLE IF NOT EXISTS la_app.properties (
    id SERIAL NOT NULL
  , name TEXT NOT NULL

  , CONSTRAINT pk_la_app_properties PRIMARY KEY( id )
);

CREATE TABLE IF NOT EXISTS la_app.key_tags (
    id SERIAL NOT NULL
  , name TEXT NOT NULL

  , CONSTRAINT pk_la_app_key_tags PRIMARY KEY( id )
);

CREATE TABLE IF NOT EXISTS la_app.keys (
    id SERIAL NOT NULL
  , account_id INTEGER NOT NULL
  , key_tag_id INTEGER NOT NULL
  , public_key TEXT NOT NULL

  , CONSTRAINT pk_la_app_keys PRIMARY KEY( id )
  , CONSTRAINT la_app_keys_uq1 UNIQUE( account_id, key_tag_id )

);
ALTER TABLE la_app.keys ADD CONSTRAINT la_app_keys_fk_1 FOREIGN KEY (account_id) REFERENCES la_app.accounts(id) NOT VALID;
ALTER TABLE la_app.keys ADD CONSTRAINT la_app_keys_fk_2 FOREIGN KEY (key_tag_id) REFERENCES la_app.key_tags(id) NOT VALID;

CREATE TABLE IF NOT EXISTS la_app.account_properties (
    id SERIAL NOT NULL
  , account_id INTEGER NOT NULL
  , property_id INTEGER NOT NULL
  , val TEXT NOT NULL

  , CONSTRAINT pk_la_account_properties PRIMARY KEY( id )
  , CONSTRAINT la_account_properties_uq1 UNIQUE( account_id, property_id )
);
ALTER TABLE la_app.account_properties ADD CONSTRAINT la_app_account_properties_fk_1 FOREIGN KEY (account_id) REFERENCES la_app.accounts(id) NOT VALID;
ALTER TABLE la_app.account_properties ADD CONSTRAINT la_app_account_properties_fk_2 FOREIGN KEY (property_id) REFERENCES la_app.properties(id) NOT VALID;

DROP FUNCTION IF EXISTS la_app.create_account;
CREATE FUNCTION la_app.create_account( _namespace TEXT, _name TEXT, _owner_key TEXT, _app_active_key TEXT, _signature bytea )
    RETURNS void
    LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __exists BOOL;
BEGIN

    SELECT EXISTS (
        SELECT 1
        FROM la_app.accounts la_a
        WHERE la_a.namespace = _namespace AND la_a.name = _name
    ) INTO __exists;

    IF NOT __exists THEN
      WITH account_inserter AS
      (
        INSERT INTO la_app.accounts( namespace, name, owner_key ) VALUES( 'game', 'avocado9', 'key' ) RETURNING id
      ),
      tag_id AS
      (
        SELECT id FROM la_app.key_tags WHERE name = 'active'
      )
      INSERT INTO la_app.keys( account_id, key_tag_id, public_key ) VALUES( ( SELECT id FROM account_inserter ), ( SELECT id FROM tag_id ), _app_active_key );

      RETURN;
    END IF;

  ASSERT FALSE, 'Account can not be created';
END;
$BODY$
;

--temporary
INSERT INTO la_app.properties( name ) VALUES( 'property 0' );
INSERT INTO la_app.properties( name ) VALUES( 'property 1' );
INSERT INTO la_app.properties( name ) VALUES( 'property 2' );

INSERT INTO la_app.key_tags( name ) VALUES( 'active' );
INSERT INTO la_app.key_tags( name ) VALUES( 'memo' );
INSERT INTO la_app.key_tags( name ) VALUES( 'battle' );
