CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __stages_correct hafd.application_stages := ARRAY[ ('stage2',100 ,100 )::hafd.application_stage, ('stage1',10 ,10 )::hafd.application_stage, hafd.live_stage() ];
    __stages_repeated_names hafd.application_stages := ARRAY[ ('live',1 ,1 )::hafd.application_stage, hafd.live_stage() ];
    __stages_repeated_hb_distance hafd.application_stages :=
        ARRAY[
            ('live1',1 ,1 )::hafd.application_stage,
            ('live2',1 ,2 )::hafd.application_stage,
            hafd.live_stage()
        ];
    __no_live_stage hafd.application_stages :=
        ARRAY[
            ('live',1 ,1 )::hafd.application_stage
            ];
BEGIN
    PERFORM hive.validate_stages( __stages_correct );

    BEGIN
       PERFORM hive.validate_stages( __stages_repeated_names );
       ASSERT FALSE, 'Duplicated name not detected';
       EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.validate_stages( __stages_repeated_hb_distance );
        ASSERT FALSE, 'Duplicated distance to head block not detected';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.validate_stages( __no_live_stage );
        ASSERT FALSE, 'Lack of live stage not detected';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$;