#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/ec2-user/jenkins-init.log 2>&1

aws ec2 create-volume --size=60 --volume-type=gp2 \
    --availability-zone=$(awk -F, '{print $1}' <<< $AWS_AVAILABILITY_ZONES) \
    --tag-specifications 'ResourceType=volume,Tags=[{Key=KubernetesCluster,Value='"$NAME"'}]' \
    > ebsVolume.json

export JENKINS_EBS_VOL_ID=$(jq -r '.VolumeId' ebsVolume.json)
export JENKINS_ADMIN_PASS=$(jq -r '.AdminPassword' /home/ec2-user/config/secrets/jenkins-secrets)

sed -ri 's/^(\s*)(volumeID\s*:\s*<X>\s*$)/\1volumeID: '"$JENKINS_EBS_VOL_ID"'/' \
    /home/ec2-user/config/k8s/pv-jenkins-home.yaml

sed -ri 's/^(\s*)(adminPassword\s*:\s*<X>\s*$)/\1adminPassword: '"$JENKINS_ADMIN_PASS"'/' \
    /home/ec2-user/config/k8s/jenkins-values.yaml

kubectl --context=${NAME} apply -f /home/ec2-user/config/k8s/pv-jenkins-home.yaml

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

#helm install --name jenkins-stg --kube-context=${NAME} -f /home/ec2-user/config/k8s/jenkins-values.yaml stable/jenkins

kubectl --context=${NAME} apply -f /home/ec2-user/config/k8s/jenkins-role.yaml

##### helm del --purge jenkins-stg
