#!/bin/bash

_MBTILES_FILE=data/osm.mbtiles
_LOCK_FILE=data/download.lock

if [[ -e $_LOCK_FILE ]]; then
    while [[ -e $_LOCK_FILE ]]; do
        echo "Waiting for MBtiles..."
        sleep 3s
    done
elif [[ -n "$SERENDITREE_DATA_URL" ]]; then
    touch $_LOCK_FILE
    echo "Downloading MBtiles..."
    curl -L "$SERENDITREE_DATA_URL" -o $_MBTILES_FILE
    rm -v $_LOCK_FILE
fi

if [[ ! -e $_MBTILES_FILE ]]; then
    echo "MBtiles do not exist. Aborting..."
    exit 1
fi

exec ./tileserver-gl-light osm.mbtiles --config config.json --bind 0.0.0.0 --port $TILESERVER_PORT
