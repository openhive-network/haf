-- Create the haf_admin role needed to own the HAF database.
-- The haf_administrators_group must exist first (created in builtin roles).
-- This file intentionally has a low number to run early, but it only creates
-- the admin role; other roles come from 025-haf-builtin-roles.sql.

DO $$
BEGIN
    -- Ensure the administrators group exists
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'haf_administrators_group') THEN
        CREATE ROLE haf_administrators_group WITH NOLOGIN SUPERUSER INHERIT CREATEDB CREATEROLE NOREPLICATION;
    END IF;

    -- Create haf_admin if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'haf_admin') THEN
        CREATE ROLE haf_admin WITH LOGIN SUPERUSER INHERIT CREATEDB NOCREATEROLE NOREPLICATION IN ROLE haf_administrators_group;
    END IF;
END
$$;
