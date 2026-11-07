-- Apply as a database administrator to gis. Password is set separately.
BEGIN;
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'martin_reader') THEN
    CREATE ROLE martin_reader LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
  END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS martin_pilot;
CREATE TABLE IF NOT EXISTS martin_pilot.points (
  id integer PRIMARY KEY,
  geom geometry(Point, 4326) NOT NULL
);
INSERT INTO martin_pilot.points VALUES (1, ST_SetSRID(ST_MakePoint(30, 50), 4326))
ON CONFLICT (id) DO NOTHING;
CREATE INDEX IF NOT EXISTS points_geom_idx ON martin_pilot.points USING gist (geom);

REVOKE ALL ON SCHEMA martin_pilot FROM PUBLIC;
REVOKE ALL ON martin_pilot.points FROM PUBLIC, martin_reader;
GRANT CONNECT ON DATABASE gis TO martin_reader;
GRANT USAGE ON SCHEMA martin_pilot TO martin_reader;
GRANT SELECT ON martin_pilot.points TO martin_reader;
COMMIT;
