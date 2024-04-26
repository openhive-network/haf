CREATE SCHEMA IF NOT EXISTS la_app;

CREATE TABLE IF NOT EXISTS la_app.accounts (
    id INTEGER NOT NULL
  , namespace TEXT NOT NULL
  , name TEXT NOT NULL
  , owner_key TEXT NOT NULL
  , active_key TEXT DEFAULT NULL

  , CONSTRAINT pk_la_app_accounts PRIMARY KEY( id )
);

CREATE TABLE IF NOT EXISTS la_app.properties (
    id INTEGER NOT NULL
  , name TEXT NOT NULL

  , CONSTRAINT pk_la_app_properties PRIMARY KEY( id )
);

CREATE TABLE IF NOT EXISTS la_app.key_tags (
    id INTEGER NOT NULL
  , name TEXT NOT NULL

  , CONSTRAINT pk_la_app_key_tags PRIMARY KEY( id )
);

CREATE TABLE IF NOT EXISTS la_app.keys (
    id INTEGER NOT NULL
  , account_id INTEGER NOT NULL
  , key_tag_id INTEGER NOT NULL
  , public_key TEXT NOT NULL

  , CONSTRAINT pk_la_app_keys PRIMARY KEY( id )
  , CONSTRAINT la_app_keys_uq1 UNIQUE( account_id, key_tag_id )

);
ALTER TABLE la_app.keys ADD CONSTRAINT la_app_keys_fk_1 FOREIGN KEY (account_id) REFERENCES la_app.accounts(id) NOT VALID;
ALTER TABLE la_app.keys ADD CONSTRAINT la_app_keys_fk_2 FOREIGN KEY (key_tag_id) REFERENCES la_app.key_tags(id) NOT VALID;

CREATE TABLE IF NOT EXISTS la_app.account_properties (
    id INTEGER NOT NULL
  , account_id INTEGER NOT NULL
  , property_id INTEGER NOT NULL
  , val TEXT NOT NULL

  , CONSTRAINT pk_la_account_properties PRIMARY KEY( id )
  , CONSTRAINT la_account_properties_uq1 UNIQUE( account_id, property_id )
);
ALTER TABLE la_app.account_properties ADD CONSTRAINT la_app_account_properties_fk_1 FOREIGN KEY (account_id) REFERENCES la_app.accounts(id) NOT VALID;
ALTER TABLE la_app.account_properties ADD CONSTRAINT la_app_account_properties_fk_2 FOREIGN KEY (property_id) REFERENCES la_app.properties(id) NOT VALID;
