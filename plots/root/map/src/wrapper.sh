#!/bin/bash

_MBTILES_FILE=data/osm.mbtiles

if [[ -n "$SERENDITREE_DATA_URL" ]] && [[ ! -e $_MBTILES_FILE ]]; then
    touch $_LOCK_FILE
    echo "Downloading MBtiles..."
    curl -L "$SERENDITREE_DATA_URL" -o $_MBTILES_FILE
fi

if [[ ! -e $_MBTILES_FILE ]]; then
    echo "MBtiles do not exist. Aborting..."
    exit 1
fi

exec ./tileserver-gl-light osm.mbtiles --config config.json --bind 0.0.0.0 --port $TILESERVER_PORT
