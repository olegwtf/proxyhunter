CREATE TYPE proxy_type AS ENUM ('HTTPS_PROXY','HTTP_PROXY','CONNECT_PROXY','SOCKS4_PROXY','SOCKS5_PROXY','DEAD_PROXY');
CREATE TABLE proxy
(
  id serial NOT NULL,
  host character varying(15) NOT NULL,
  port integer NOT NULL,
  checked boolean NOT NULL DEFAULT false,
  checkdate timestamp without time zone NOT NULL DEFAULT '1980-01-01 00:00:00'::timestamp without time zone,
  speed_checkdate timestamp without time zone NOT NULL DEFAULT '1980-01-01 00:00:00'::timestamp without time zone,
  fails smallint NOT NULL DEFAULT 0,
  type proxy_type NOT NULL DEFAULT 'DEAD_PROXY'::proxy_type,
  in_progress boolean NOT NULL DEFAULT false,
  conn_time integer DEFAULT NULL,
  speed integer NOT NULL DEFAULT 0,
  CONSTRAINT proxy_pk PRIMARY KEY (id),
  CONSTRAINT proxy_uniq UNIQUE (host, port)
);
CREATE INDEX sort_idx
  ON proxy
  USING btree
  (checked, checkdate);
CREATE INDEX type_idx
  ON proxy
  USING btree
  (type);
