DO $$
BEGIN
    CREATE ROLE haf_admin WITH
      LOGIN
      SUPERUSER
      INHERIT
      CREATEDB
      NOCREATEROLE
      NOREPLICATION
      IN ROLE haf_administrators_group
      ;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'haf_admin already exists';
END
$$;
