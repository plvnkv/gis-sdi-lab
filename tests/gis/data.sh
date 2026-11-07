#!/usr/bin/env bash
set -euo pipefail
: "${GIS_CONTEXT:?Set the test Kubernetes context}"
: "${GIS_S3_ENDPOINT:?Set the test S3 endpoint}"
: "${GIS_S3_TEST_BUCKET:?Set a dedicated pre-existing test bucket}"
: "${AWS_ACCESS_KEY_ID:?Set test bucket access key}"
: "${AWS_SECRET_ACCESS_KEY:?Set test bucket secret key}"

kubectl --context "$GIS_CONTEXT" -n gis exec -i deploy/postgis -- \
  psql -X -v ON_ERROR_STOP=1 -U postgres -d gis <<'SQL'
SELECT PostGIS_Full_Version();
CREATE TEMP TABLE gis_smoke (geom geometry(Point, 4326));
INSERT INTO gis_smoke VALUES (ST_SetSRID(ST_MakePoint(30, 50), 4326));
DO $$
BEGIN
  IF (SELECT ST_AsText(geom) FROM gis_smoke) IS DISTINCT FROM 'POINT(30 50)' THEN
    RAISE EXCEPTION 'Unexpected geometry';
  END IF;
END
$$;
SQL
kubectl --context "$GIS_CONTEXT" -n gis exec deploy/postgis -- \
  psql -X -v ON_ERROR_STOP=1 -U postgres -d geonode -c 'SELECT current_database();'

tmp=$(mktemp -d)
key="gis-smoke/${tmp##*/}-$(date +%s)"
s3() { aws --endpoint-url "$GIS_S3_ENDPOINT" s3api "$@"; }
trap 'rm -rf "$tmp"' EXIT
printf 'gis-smoke\n' > "$tmp/object"
s3 put-object --bucket "$GIS_S3_TEST_BUCKET" --key "$key" --body "$tmp/object" >/dev/null
cleanup() {
  s3 delete-object --bucket "$GIS_S3_TEST_BUCKET" --key "$key" >/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT
s3 head-object --bucket "$GIS_S3_TEST_BUCKET" --key "$key" >/dev/null
s3 get-object --bucket "$GIS_S3_TEST_BUCKET" --key "$key" --range bytes=0-2 "$tmp/range" >/dev/null
test "$(cat "$tmp/range")" = gis
s3 delete-object --bucket "$GIS_S3_TEST_BUCKET" --key "$key" >/dev/null
trap 'rm -rf "$tmp"' EXIT
echo 'PASS: PostGIS geometry and RustFS range reads'
