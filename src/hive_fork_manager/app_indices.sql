-- Tracks which application needs which app index
CREATE TABLE IF NOT EXISTS hafd.app_indices_contexts_map (
    app_index_id INTEGER NOT NULL,
    context_id INTEGER NOT NULL,
    PRIMARY KEY (app_index_id, context_id),
    CONSTRAINT fk_app_indices_contexts_map_app_index_id FOREIGN KEY (app_index_id) REFERENCES hafd.indexes_constraints (id),
    CONSTRAINT fk_app_indices_contexts_map_context_id FOREIGN KEY (context_id) REFERENCES hafd.contexts (id)
);

-- Declares that given app needs given index
CREATE OR REPLACE PROCEDURE hive.register_app_index(_context_name hafd.context_name, _table_name TEXT, _index_name TEXT, _index_content TEXT)
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
    index_id INTEGER;
    worker_id INTEGER;
BEGIN
  INSERT INTO hafd.indexes_constraints(table_name, index_constraint_name, command, status, is_app_defined, is_constraint, is_index, is_foreign_key)
    VALUES (_table_name, _index_name, _index_content, 'missing', TRUE, FALSE, TRUE, FALSE)
    RETURNING id INTO index_id;

  INSERT INTO hafd.app_indices_contexts_map(app_index_id, context_id)
    SELECT index_id, c.id
    FROM hafd.contexts AS c
    WHERE c.name = _context_name;

  IF hive.is_instance_ready() THEN
    SELECT * FROM pg_background_launch(_index_content) INTO worker_id;
    PERFORM pg_sleep(0.1); -- https://github.com/vibhorkum/pg_background/issues/6
    PERFORM pg_background_detach(worker_id); -- https://github.com/vibhorkum/pg_background/issues/40
  END IF;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE hive.wait_till_registered_indexes_created(
    app_context_name TEXT
)
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    _missing_indices integer;
BEGIN
    LOOP
      SELECT COUNT(*)
        INTO _missing_indices
        FROM hafd.indexes_constraints AS i
        JOIN hafd.app_indices_contexts_map AS map ON i.id = map.app_index_id
        JOIN hafd.contexts AS c ON c.id = map.context_id
        WHERE c.name = app_context_name
          AND status <> 'created'
          AND is_app_defined = true;

          IF _missing_indices = 0 THEN
            RETURN;
          END IF;

        PERFORM pg_sleep(1);
    END LOOP;
END;
$BODY$;

