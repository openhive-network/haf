



CREATE EXTENSION  IF NOT EXISTS pldbgapi;




CREATE or replace  PROCEDURE hive.mtk_run01()
language plpgsql
as 
$$
declare
begin
IF not hive.app_context_exists( 'accounts_ctx' ) THEN
	PERFORM hive.app_create_context( 'accounts_ctx');
END IF;
End;
$$
;

CREATE or replace  PROCEDURE hive.mtk_run_02()
language plpgsql
as 
$$
declare
begin
CREATE TABLE IF NOT EXISTS public.trx_histogram(
	  day DATE
	, trx INT
	, CONSTRAINT pk_trx_histogram PRIMARY KEY( day ) )
INHERITS( hive.accounts_ctx );
end;
$$
;


CREATE or replace  PROCEDURE hive.mtk_run_03()
language plpgsql
as 
$$
declare
begin
perform hive.app_state_provider_import( 'ACCOUNTS', 'accounts_ctx' );
end;
$$
;

CREATE or replace  PROCEDURE hive.mtk_run_remove_context()
language plpgsql
as 
$$
declare
begin
perform  hive.app_remove_context('accounts_ctx');
--perform hive.app_state_provider_drop( 'ACCOUNTS', 'accounts_ctx' );
end;
$$
;




-- Create or replace procedure hive.app_state_providers_update_wrapper( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
-- language plpgsql
-- as 
-- $BODY$
-- begin
-- 	perform hive.app_state_providers_update( _first_block, _last_block, _context );
-- end;
-- $BODY$
-- ;



CREATE or replace  PROCEDURE hive.mtk_run_04()
language plpgsql
as 
$$
declare
	APPLICATION_CONTEXT TEXT:= 'accounts_ctx';
	name   character varying(255);

	blocks_range hive.blocks_range;
	ace hive.accounts%ROWTYPE;

begin

-- main loop

SELECT into blocks_range * FROM hive.app_next_block( 'accounts_ctx' ) LIMIT 1;
raise warning E'\n%', blocks_range;


SELECT into ace  * FROM hive.accounts_ctx_accounts ORDER BY id DESC LIMIT 1;
raise warning E'\n%', ace;

IF (select hive.app_context_is_attached('accounts_ctx') )AND blocks_range.first_block != blocks_range.last_block  then
	perform hive.app_context_detach('accounts_ctx');
end if;

PERFORM hive.app_state_providers_update( blocks_range.first_block, blocks_range.last_block, APPLICATION_CONTEXT);
raise warning 'ENDING NOW';

if not (select  hive.app_context_is_attached('accounts_ctx')) then
	perform hive.app_context_attach('accounts_ctx');
end if;

end;
$$
;




CREATE or replace  PROCEDURE hive.mtk_run_all()
language plpgsql
as 
$$
declare
	APPLICATION_CONTEXT TEXT:= 'accounts_ctx';
	name   character varying(255);

	blocks_range hive.blocks_range;
	ace hive.accounts%ROWTYPE;
	CNT INTEGER := -1;

begin

perform  hive.app_remove_context('accounts_ctx');

IF not hive.app_context_exists( 'accounts_ctx' ) THEN
	PERFORM hive.app_create_context( 'accounts_ctx');
END IF;

perform hive.app_state_provider_import( 'ACCOUNTS', 'accounts_ctx' );


-- main loop

SELECT into blocks_range * FROM hive.app_next_block( 'accounts_ctx' ) LIMIT 1;
raise warning E'\n%', blocks_range;


IF (select hive.app_context_is_attached('accounts_ctx') )AND blocks_range.first_block != blocks_range.last_block  then
	perform hive.app_context_detach('accounts_ctx');
end if;

PERFORM hive.app_state_providers_update( blocks_range.first_block, blocks_range.last_block, APPLICATION_CONTEXT);
raise warning 'ENDING NOW';

if not (select  hive.app_context_is_attached('accounts_ctx')) then
	perform hive.app_context_attach('accounts_ctx');
end if;

SELECT into cnt  count(*) FROM hive.accounts_ctx_accounts_view;
raise warning '%', cnt;


end;
$$
;


