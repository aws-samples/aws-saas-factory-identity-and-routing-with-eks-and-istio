#!/usr/bin/bash
. ~/.bash_profile

echo "Creating namespaces"
kubectl create namespace cluster1-tenantc-oidc-proxy-ns
kubectl create namespace cluster1-tenantc-ns

echo "Updating Istio Gateway config"
python3 update-gateway-config.py

kubectl -n cluster1-gateway-ns apply -f ${YAML_PATH}/cluster1-gateway.yaml

echo "Updating Envoy Config"
python3 update-envoy-config.py

REPO_NAME="envoyproxy"

ECR_REPO=$(aws ecr describe-repositories --repository-names $REPO_NAME)

REPO_URI=$(echo $ECR_REPO|jq -r '.repositories[0].repositoryUri')

aws ecr batch-delete-image --repository-name $REPO_NAME --image-ids imageTag=latest
docker image rm -f $(docker images envoy:v1 --format "{{.ID}}")

echo "Re-building Docker Image"
docker build -t envoy:v1 .

echo "Pushing Docker Image to ECR Repo"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS \
  --password-stdin $REPO_URI
docker tag $(docker images envoy:v1 --format "{{.ID}}") \
  $REPO_URI:latest
docker push $REPO_URI:latest

echo "Re-deploying Envoy Reverse Proxy"
kubectl rollout restart deployment/envoy-reverse-proxy \
  -n cluster1-envoy-reverse-proxy-ns

echo "Configuring AuthorizationPolicy on Istio Ingress Gateway"
kubectl apply -f ${YAML_PATH}/cluster1-auth-policy.yaml