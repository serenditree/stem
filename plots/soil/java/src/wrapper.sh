#!/usr/bin/env bash

echo "Waiting for source..."
until [[ -f src/release ]]; do sleep .2; done

echo "Starting build..."
pushd src >/dev/null || exit 1
mvn clean install --also-make --projects leaves/leaf-${SERENDITREE_BRANCH}
popd >/dev/null || exit 1

echo "Moving build artifacts..."
mv src/leaves/leaf-${SERENDITREE_BRANCH}/target/serenditree/* .

echo "Starting ${SERENDITREE_SERVICE}..."
exec bash run.sh
