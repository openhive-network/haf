
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION csp_driver_extension;
    --drop extension if exists csp_driver_extension;
    --create extension csp_driver_extension; 
    select 

-- bool run_consensus_replay(
--     const std::string& context,
--     const std::string& consensus_state_provider_storage,
--     const std::string& postgres_url,
--     int from, int to, int step)

        run_consensus_replay_pg(
            'driverc',                                      -- context
            '/home/hived/datadir/consensus_state_provider', -- consensus_state_provider_storage
            'postgresql:///haf_block_log',                  -- postgres_url
            1,                                              -- from 
            5000000,                                        -- to
            100000);                                        -- step
END;
$BODY$
;

-- CREATE OR REPLACE PROCEDURE haf_admin_test_when()
-- LANGUAGE 'plpgsql'
    
-- $BODY$
-- BEGIN

-- END;
-- $BODY$
-- ;

-- CREATE OR REPLACE PROCEDURE haf_admin_test_then()
--         LANGUAGE 'plpgsql'
-- AS
-- $BODY$
-- BEGIN
-- END;
-- $BODY$
-- ;
