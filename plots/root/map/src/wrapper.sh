#!/bin/bash

if [[ ! -f data/osm.mbtiles ]]; then
    echo "Database osm.mbtiles does not exist. Aborting..."
    exit 1
fi

exec ./tileserver-gl-light osm.mbtiles --config config.json --bind 0.0.0.0 --port $TILESERVER_PORT
