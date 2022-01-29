DO $$
BEGIN
    CREATE ROLE hived_group WITH NOLOGIN;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hived_group role already exists';
END
$$;

DO $$
BEGIN
    CREATE ROLE hive_applications_group WITH NOLOGIN;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hive_applications_group role already exists';
END
$$;

DO $$
BEGIN
    CREATE ROLE haf_administrators_group WITH NOLOGIN SUPERUSER
    INHERIT
      CREATEDB
      NOCREATEROLE
      NOREPLICATION;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'haf_administrators_group role already exists';
END
$$;

DO $$
BEGIN
    CREATE ROLE hive WITH LOGIN CREATEDB INHERIT IN ROLE hive_applications_group;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hive role already exists';
END
$$;

DO $$
BEGIN
    CREATE ROLE hived WITH LOGIN INHERIT IN ROLE hived_group;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hived role already exists';
END
$$;
