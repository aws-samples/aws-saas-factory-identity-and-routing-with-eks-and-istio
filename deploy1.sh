#!/usr/bin/bash
source ~/.bash_profile

export EKS_CLUSTER_NAME="istio-saas"
test -n "$EKS_CLUSTER_NAME" && echo EKS_CLUSTER_NAME is "$EKS_CLUSTER_NAME" || echo EKS_CLUSTER_NAME is not set
echo "export EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME}" | tee -a ~/.bash_profile

export MASTER_ARN=$(aws kms describe-key --key-id alias/istio-ref-arch --query KeyMetadata.Arn --output text)

echo "Deploying EKS Cluster ${EKS_CLUSTER_NAME}"

cat << EOF > ${YAML_PATH}/istio-cluster-config.yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: istio-saas
  region: ${AWS_REGION}
  version: "1.21"
iam:
  withOIDC: true
  serviceAccounts:
  - metadata:
      name: aws-load-balancer-controller
      namespace: kube-system
    wellKnownPolicies:
      awsLoadBalancerController: true
#
# Addons, Security
#
availabilityZones: ["${AWS_REGION}a", "${AWS_REGION}b", "${AWS_REGION}c"]
managedNodeGroups:
- name: nodegroup
  desiredCapacity: 3
  instanceTypes: ["t3a.medium","t3.medium"]
  spot: true
  volumeEncrypted: true
  ssh:
    allow: true
    publicKeyName: istio-saas
# To enable all of the control plane logs, uncomment below:
# cloudWatch:
#  clusterLogging:
#    enableTypes: ["*"]
secretsEncryption:
  keyARN: ${MASTER_ARN}
EOF

eksctl create cluster -f ${YAML_PATH}/istio-cluster-config.yaml

echo "Installing AWS Load Balancer Controller"

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts

helm repo update

# Setting AWS Load Balancer Controller Version
export LBC_VERSION="v2.4.0"

export VPC_ID=$(aws eks describe-cluster \
                --name ${EKS_CLUSTER_NAME} \
                --query "cluster.resourcesVpcConfig.vpcId" \
                --output text)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${EKS_CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set region=${AWS_REGION} \
  --set vpcId=${VPC_ID} \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl -n kube-system rollout status deployment aws-load-balancer-controller
