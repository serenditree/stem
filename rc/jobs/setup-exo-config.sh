#!/usr/bin/env bash
kubectl create secret generic exoscale-config --from-file=$EXOSCALE_CONFIG --namespace serenditree
