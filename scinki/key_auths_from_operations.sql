-----------------------------------------------------------------------------------------------------------
SELECT
  (json_extract_path_text( CAST( body as json ), 'value', 'owner','key_auths')) as owner,
  (json_extract_path_text( CAST( body as json ), 'value', 'active','key_auths')) as active,
(json_extract_path_text( CAST( body as json ), 'value', 'posting','key_auths')) as posting,
count(*) as count
							   FROM hive.operations


where 

body ~*  'key_auths'
group by owner,active,posting
order by count asc;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
  (json_extract_path_text( CAST( body as json ), 'value', 'owner','key_auths')) as owner,
  json_array_length(
	cast (
		json_extract_path_text( CAST( body as json ), 'value', 'owner','key_auths')  as json))as ownerLen,
  (json_extract_path_text( CAST( body as json ), 'value', 'active','key_auths')) as active,
(json_extract_path_text( CAST( body as json ), 'value', 'posting','key_auths')) as posting,
array_agg(body) as bdy1,
count(*) as count

							   FROM hive.operations


where 
body ~*  'key_auths'

and

  json_array_length(
	cast (
		json_extract_path_text( CAST( body as json ), 'value', 'owner','key_auths')  as json)) > 2
		
group by owner,active,posting
order by ownerlen asc;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT body
operation,
 owner,
  active,
posting,
 count
FROM

(SELECT
	 body,
   (json_extract_path_text( CAST( body as json ), 'type' ))as operation,
  (json_extract_path_text( CAST( body as json ), 'value', 'owner','key_auths')) as owner,
  (json_extract_path_text( CAST( body as json ), 'value', 'active','key_auths')) as active,
(json_extract_path_text( CAST( body as json ), 'value', 'posting','key_auths')) as posting,
count(*) as count
							   FROM hive.operations


where 

body ~*  'key_auths'


group by owner,active,posting,operation,body
order by count asc)as aliasowy

WHERE operation = 'request_account_recovery_operation'
-----------------------------------------------------------------------------------------------------------

