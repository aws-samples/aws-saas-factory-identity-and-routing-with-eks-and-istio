#!/usr/bin/bash
. ~/.bash_profile

TENANTS="tenanta tenantb tenantc"

echo "Removing User Pools"

for t in $TENANTS
do
    POOLNAME=${t}_example_com
    QUERY='UserPools[?Name==`'${POOLNAME}'`].Id'
    POOLID=$(aws cognito-idp list-user-pools --max-results 20 --query $QUERY --output text)
    DOMAIN=$(aws cognito-idp describe-user-pool --user-pool-id ${POOLID} --query 'UserPool.Domain' --output text)

    aws cognito-idp delete-user-pool-domain \
      --user-pool-id ${POOLID} \
      --domain ${DOMAIN}

    aws cognito-idp delete-user-pool \
      --user-pool-id ${POOLID}

done

echo "Uninstalling AWS Load Balancer Controller"
helm uninstall aws-load-balancer-controller \
    -n kube-system

echo "Deleting ECR Repository"
aws ecr delete-repository \
  --force \
  --repository-name envoyproxy  2>&1 > /dev/null

echo "Deleting EKS Cluster"
eksctl delete cluster --name istio-saas

echo "Removing KMS Key and Alias"
export MASTER_ARN=$(aws kms describe-key \
  --key-id alias/istio-ref-arch\
  --query KeyMetadata.Arn --output text)

aws kms disable-key \
  --key-id ${MASTER_ARN}

aws kms delete-alias \
  --alias-name alias/istio-ref-arch

echo "Deleting EC2 Key-Pair"
aws ec2 delete-key-pair \
  --key-name "istio-saas"