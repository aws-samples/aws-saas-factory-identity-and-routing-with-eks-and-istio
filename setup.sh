#!/usr/bin/env bash
. ~/.bash_profile

echo "Installing kubectl"
sudo curl --silent --no-progress-meter --location -o /usr/local/bin/kubectl \
  https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl

sudo chmod +x /usr/local/bin/kubectl

kubectl version --short –client

echo "Installing bash completion for kubectl"
kubectl completion bash >>  ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion

echo "Installing eksctl"
curl --silent --no-progress-meter --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

sudo mv -v /tmp/eksctl /usr/local/bin

eksctl version

echo "Installing bash completion for eksctl"
eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion

echo "Installing AWS CLI v2"
curl --no-progress-meter "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -qq awscliv2.zip
sudo ./aws/install
PATH=/usr/local/bin:$PATH
/usr/local/bin/aws --version
rm -rf aws awscliv2.zip

echo "Installing helper tools"
sudo yum -y -q install jq bash-completion
sudo pip3 -q install PyYAML

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl --no-progress-meter -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
export AWS_DEFAULT_REGION=$AWS_REGION
export YAML_PATH=yaml
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
echo "export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region
echo "export YAML_PATH=yaml" | tee -a ~/.bash_profile
[ -d ${YAML_PATH} ] || mkdir ${YAML_PATH}

echo "Installing helm"
curl --no-progress-meter -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm version --template='Version: {{.Version}}'; echo


rm -vf ${HOME}/.aws/credentials

echo "Generating a new key. Hit ENTER three times when prompted to accept the defaults"
ssh-keygen

aws ec2 import-key-pair --key-name "istio-saas" --public-key-material fileb://~/.ssh/id_rsa.pub

aws kms create-alias --alias-name alias/istio-ref-arch --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)

export MASTER_ARN=$(aws kms describe-key --key-id alias/istio-ref-arch --query KeyMetadata.Arn --output text)

echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bash_profile

aws sts get-caller-identity --query Arn | grep istio-ref-arch-admin -q && echo "IAM role valid. You can continue setting up the EKS Cluster." || echo "IAM role NOT valid. Do not proceed with creating the EKS Cluster or you won't be able to authenticate. Ensure you assigned the role to your EC2 instance as detailed in the README.md of the istio-saas repo"
