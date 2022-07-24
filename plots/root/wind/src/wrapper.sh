#!/usr/bin/env bash

echo "Starting zookeeper..."
${KAFKA_PATH}/bin/zookeeper-server-start.sh ${KAFKA_PATH}/config/zookeeper.properties &
until ${KAFKA_PATH}/bin/zookeeper-shell.sh 127.0.0.1:2181 config &>/dev/null; do sleep .5; done

echo "Starting kafka..."
${KAFKA_PATH}/bin/kafka-server-start.sh ${KAFKA_PATH}/config/server.properties \
    --override listeners=PLAINTEXT://0.0.0.0:${KAFKA_PORT} \
    --override advertised.listeners=PLAINTEXT://${KAFKA_HOST:-127.0.0.1}:${KAFKA_PORT} &
until bash health.sh &>/dev/null; do sleep .5; done

for _topic in $KAFKA_TOPICS; do
    echo "Creating topic '$_topic'..."
    ${KAFKA_PATH}/bin/kafka-topics.sh --create \
        --bootstrap-server 127.0.0.1:${KAFKA_PORT} \
        --replication-factor 1 \
        --partitions 1 \
        --topic "$_topic"
done

while sleep 10s; do
   bash health.sh || { echo "Kafka is down..." && exit 1; }
done
