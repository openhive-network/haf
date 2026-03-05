ALTER TABLE hafd.contexts
ADD CONSTRAINT fk_hive_app_context FOREIGN KEY(events_id) REFERENCES hafd.events_queue( id );
