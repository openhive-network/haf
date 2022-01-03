CREATE TABLE IF NOT EXISTS hive.fork(
    id BIGSERIAL NOT NULL,
    block_num INT NOT NULL,
    time_of_fork TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_hive_fork PRIMARY KEY( id )
);

INSERT INTO hive.fork(block_num, time_of_fork) VALUES( 1, '2016-03-24 16:05:00'::timestamp )
    ON CONFLICT DO NOTHING;