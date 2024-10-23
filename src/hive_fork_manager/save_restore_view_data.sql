CREATE SEQUENCE hafd.deps_saved_ddl_deps_id_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;


CREATE TABLE hafd.deps_saved_ddl
(
    deps_id integer NOT NULL DEFAULT nextval('hafd.deps_saved_ddl_deps_id_seq'::regclass),
    deps_view_schema character varying(255),
    deps_view_name character varying(255),
    deps_ddl_to_run text,
    CONSTRAINT deps_saved_ddl_pkey PRIMARY KEY (deps_id)
)
;