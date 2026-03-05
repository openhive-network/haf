CREATE OR REPLACE FUNCTION contexts_insert_trigger()
    RETURNS trigger
    LANGUAGE plpgsql
AS
$BODY$
    DECLARE
       __number_of_contexts INTEGER;
    BEGIN
        SELECT COUNT( hc.* ) INTO __number_of_contexts FROM hafd.contexts hc WHERE hc.owner = current_user;

        IF ( __number_of_contexts > 1000 ) THEN
            RAISE EXCEPTION 'User % cannot create a new context %. The limit of 1000 contexts has been reached.', current_user, NEW.name;
        END IF;

        RETURN NEW;
    END;
$BODY$
;


DROP TRIGGER IF EXISTS hive_contexts_limit_trigger ON hafd.contexts;
CREATE TRIGGER hive_contexts_limit_trigger AFTER INSERT ON hafd.contexts FOR EACH ROW EXECUTE FUNCTION contexts_insert_trigger();
