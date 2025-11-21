-- check if blocks are not pruned when there is only one contexts but 2 are required

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM test.fill_with_blocks_data();

    CREATE SCHEMA A;
    PERFORM hive.app_create_context(  _name =>'context1', _schema => 'a', _is_attached := FALSE );

    PERFORM hive.app_set_current_block_num( 'context1', 5 );

    UPDATE hafd.contexts
    SET irreversible_block = 5
    WHERE name ='context1';

    UPDATE hafd.contexts
    SET irreversible_block = 3
    WHERE name ='context2';

    UPDATE hafd.hive_stable_state
    SET pruning = 5,
        pruning_min_contexts = 2
    ;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.prune_blocks_data(2);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT hive.is_pruning_allowed() = false, 'Pruning is enabled, but there is only one context';
END;
$BODY$
;