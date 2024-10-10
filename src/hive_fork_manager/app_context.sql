ALTER TABLE hive_data.contexts
ADD CONSTRAINT fk_hive_app_context FOREIGN KEY(events_id) REFERENCES hive_data.events_queue( id ),
ADD CONSTRAINT fk_2_hive_app_context FOREIGN KEY(fork_id) REFERENCES hive_data.fork( id );
