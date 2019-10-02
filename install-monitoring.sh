#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/ec2-user/monitoring-init.log 2>&1

kubectl --context=${NAME} apply -f /home/ec2-user/config/k8s/monitoring/configmap/grafana-config.yaml

sleep 5s;

helm install stable/prometheus --namespace monitoring --name prometheus

sleep 15s;

helm install stable/grafana \
    -f /home/ec2-user/config/k8s/monitoring/grafana-chart-values.yaml \
    --namespace monitoring \
    --name grafana

#kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

##### helm del --purge grafana
##### helm del --purge prometheus

