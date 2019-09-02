#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/ec2-user/init-log.log 2>&1

echo $(pwd) > /home/ec2-user/init-pwd.out

yum update -y
yum install jq -y

curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x ./kops
mv ./kops /usr/local/bin/

wget https://get.helm.sh/helm-v2.14.3-linux-amd64.tar.gz
tar zxvf helm-v2.14.3-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/
rm helm-v2.14.3-linux-amd64.tar.gz
rm -rf ./linux-amd64/

chmod -R +x /home/ec2-user/config

chown -R ec2-user:ec2-user /home/ec2-user/config

#aws iam create-group --group-name kops

#aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
#aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
#aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
#aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
#aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops

#aws iam create-user --user-name kops
#aws iam add-user-to-group --user-name kops --group-name kops

aws iam list-access-keys --user-name kops > kopsCreds.json
aws iam delete-access-key --access-key $(jq -r '.AccessKeyMetadata[0].AccessKeyId' kopsCreds.json) --user-name kops

aws iam create-access-key --user-name kops > kopsCreds.json

export AWS_ACCESS_KEY_ID=$(jq -r '.AccessKey.AccessKeyId' kopsCreds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.AccessKey.SecretAccessKey' kopsCreds.json)
export AWS_DEFAULT_REGION=eu-central-1
export AWS_AVAILABILITY_ZONES=eu-central-1a,eu-central-1b

sleep 30s

#aws s3api create-bucket \
#    --bucket surf-advisor-state-store \
#    --create-bucket-configuration LocationConstraint=$(echo "$AWS_DEFAULT_REGION")

#aws s3api put-bucket-versioning --bucket surf-advisor-state-store --versioning-configuration Status=Enabled
#aws s3api put-bucket-encryption --bucket surf-advisor-state-store --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

export NAME=surfadvisor.k8s.local
export KOPS_STATE_STORE=s3://surf-advisor-state-store

echo '#!/bin/sh' > /etc/profile.d/env-setup.sh
printf '\n' >> /etc/profile.d/env-setup.sh
printenv | sed -e 's/^/export /g' >> /etc/profile.d/env-setup.sh

ssh-keygen -b 2048 -t rsa -f /home/ec2-user/.ssh/id_rsa -q -N ""

kops create secret --name ${NAME} sshpublickey admin -i /home/ec2-user/.ssh/id_rsa.pub

kops create cluster  --name ${NAME} --zones $(echo "$AWS_AVAILABILITY_ZONES") \
    --master-size m3.medium --master-count 1 \
    --node-size t3.medium --node-count 2

kops update cluster ${NAME} --yes

# sleep 8m; kubectl apply -f /home/ec2-user/config/secrets; helm init; sleep 30s; bash /home/ec2-user/config/install-jenkins.sh; bash /home/ec2-user/config/install-istio.sh

#### kops delete cluster --name ${NAME} --yes
