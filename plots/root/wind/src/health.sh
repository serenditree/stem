#!/usr/bin/env bash

${KAFKA_PATH}/bin/kafka-topics.sh --list --bootstrap-server 127.0.0.1:${KAFKA_PORT} >/dev/null && echo "Kafka is up..."
