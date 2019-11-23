#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/ec2-user/autoscaling-init.log 2>&1

CLOUD_PROVIDER=aws
IMAGE=k8s.gcr.io/cluster-autoscaler:v1.2.2
MIN_NODES=1
MAX_NODES=5
INSTANCE_GROUP_NAME="nodes"
# For AWS GROUP_NAME should be the name of ASG as seen on AWS console
GROUP_NAME="${INSTANCE_GROUP_NAME}.${NAME}"
IAM_ROLE="masters.${NAME}"
SSL_CERT_PATH="/etc/ssl/certs/ca-certificates.crt" # (/etc/ssl/certs for gce, /etc/ssl/certs/ca-bundle.crt for RHEL7.X)

aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name ${GROUP_NAME} \
    --min-size ${MIN_NODES} --max-size ${MAX_NODES}

addon=/home/ec2-user/config/k8s/autoscaling/cluster-autoscaler.yaml

sed -i -e "s@{{CLOUD_PROVIDER}}@${CLOUD_PROVIDER}@g" "${addon}"
sed -i -e "s@{{IMAGE}}@${IMAGE}@g" "${addon}"
sed -i -e "s@{{MIN_NODES}}@${MIN_NODES}@g" "${addon}"
sed -i -e "s@{{MAX_NODES}}@${MAX_NODES}@g" "${addon}"
sed -i -e "s@{{GROUP_NAME}}@${GROUP_NAME}@g" "${addon}"
sed -i -e "s@{{AWS_REGION}}@${AWS_DEFAULT_REGION}@g" "${addon}"
sed -i -e "s@{{SSL_CERT_PATH}}@${SSL_CERT_PATH}@g" "${addon}"

kubectl apply -f /home/ec2-user/config/k8s/autoscaling
