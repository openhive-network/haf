DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    --Nothing to do
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_comment_operation;
CREATE PROCEDURE check_operation_to_comment_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.comment_operation;
BEGIN
  op := '{"type": "comment_operation", "value": {"author": "tattoodjay", "body": "This is a cross post of [@tattoodjay/wednesday-walk-in-buttonwood-park](/hive-194913/@tattoodjay/wednesday-walk-in-buttonwood-park) by @tattoodjay.<br><br>A walk around Buttonwood Park", "json_metadata": "{\"app\":\"peakd/2023.2.2\",\"tags\":[\"cross-post\"],\"image\":[],\"original_author\":\"tattoodjay\", \"original_permlink\":\"wednesday-walk-in-buttonwood-park\"}", "parent_author": "", "parent_permlink": "hive-155530", "permlink": "wednesday-walk-in-buttonwood-park-hive-155530", "title": "Wednesday Walk in Buttonwood Park"}}'::hive.operation::hive.comment_operation;
  ASSERT (select op.parent_author = ''), format('Unexpected value of comment_operation.parent_author: %s', op.parent_author);
  ASSERT (select op.parent_permlink = 'hive-155530'), format('Unexpected value of comment_operation.parent_permlink: %s', op.parent_permlink);
  ASSERT (select op.author = 'tattoodjay'), format('Unexpected value of comment_operation.author: %s', op.author);
  ASSERT (select op.permlink = 'wednesday-walk-in-buttonwood-park-hive-155530'), format('Unexpected value of comment_operation.permlink: %s', op.permlink);
  ASSERT (select op.title = 'Wednesday Walk in Buttonwood Park'), format('Unexpected value of comment_operation.title: %s', op.title);
  ASSERT (select op.body = 'This is a cross post of [@tattoodjay/wednesday-walk-in-buttonwood-park](/hive-194913/@tattoodjay/wednesday-walk-in-buttonwood-park) by @tattoodjay.<br><br>A walk around Buttonwood Park'), format('Unexpected value of comment_operation.body: %s', op.body);
  ASSERT (select op.json_metadata = '{"app": "peakd/2023.2.2", "tags": ["cross-post"], "image": [], "original_author": "tattoodjay", "original_permlink": "wednesday-walk-in-buttonwood-park"}'), format('Unexpected value of comment_operation.json_metadata: %s', op.json_metadata);
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
  CALL check_operation_to_comment_operation();
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    --Nothing to do
END;
$BODY$
;


