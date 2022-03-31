#!/usr/bin/bash
. ~/.bash_profile

# Directory for generated certs
mkdir certs

echo "Creating Root CA Cert and Key"
openssl req -x509 -sha256 -nodes -days 365 \
  -newkey rsa:2048 \
  -subj '/O=Cluster 1 CA/CN=cluster1ca.example.com' \
  -keyout certs/cluster1ca_example_com.key \
  -out certs/cluster1ca_example_com.crt

echo "Creating Cert and Key for Istio Ingress Gateway"
openssl req \
  -newkey rsa:2048 -nodes \
  -subj "/O=Cluster 1/CN=*.example.com" \
  -keyout certs/cluster1_example_com.key \
  -out certs/cluster1_example_com.csr

openssl x509 -req -days 365 \
  -set_serial 0 \
  -CA certs/cluster1ca_example_com.crt \
  -CAkey certs/cluster1ca_example_com.key \
  -in certs/cluster1_example_com.csr \
  -out certs/cluster1_example_com.crt

echo "Creating TLS secret for Istio Ingress Gateway"
kubectl create -n istio-system secret generic cluster1-credentials \
  --from-file=tls.key=certs/cluster1_example_com.key \
  --from-file=tls.crt=certs/cluster1_example_com.crt \
  --from-file=ca.crt=certs/cluster1ca_example_com.crt

echo "Creating namespaces"
kubectl create namespace cluster1-gateway-ns
kubectl create namespace cluster1-envoy-reverse-proxy-ns
kubectl create namespace cluster1-tenanta-oidc-proxy-ns
kubectl create namespace cluster1-tenantb-oidc-proxy-ns
kubectl create namespace cluster1-tenanta-ns
kubectl create namespace cluster1-tenantb-ns

echo "Deploying Istio Gateway resource"
cat << EOF > ${YAML_PATH}/cluster1-gateway.yaml
---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: gateway
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: cluster1-credentials
        minProtocolVersion: TLSV1_2
        maxProtocolVersion: TLSV1_3
      hosts:
        - 'cluster1-tenanta-ns/*'
        - 'cluster1-tenantb-ns/*'
EOF
kubectl -n cluster1-gateway-ns apply -f ${YAML_PATH}/cluster1-gateway.yaml

echo "Creating ECR Repository"
ECR_REPO=$(aws ecr create-repository \
  --repository-name envoyproxy \
  --encryption-configuration encryptionType=KMS)
  
REPO_URI=$(echo $ECR_REPO|jq -r '.repository.repositoryUri')

echo "Building Docker Image"
cp envoy.yaml.orig envoy.yaml
docker build -t envoy:v1 .

echo "Pushing Docker Image to ECR Repo"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS \
  --password-stdin $REPO_URI
docker tag $(docker images envoy:v1 --format "{{.ID}}") \
  $REPO_URI:latest
docker push $REPO_URI:latest

echo "Deploying Envoy Reverse Proxy"
cat << EOF > ${YAML_PATH}/envoy-reverse-proxy.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: envoy-reverse-proxy-sa
---
apiVersion: v1
kind: Service
metadata:
  name: envoy-reverse-proxy
  labels:
    app: envoy-reverse-proxy
spec:
  selector:
    app: envoy-reverse-proxy
  ports:
  - port: 80
    name: http
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envoy-reverse-proxy
  labels:
    app: envoy-reverse-proxy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: envoy-reverse-proxy
  minReadySeconds: 60
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: envoy-reverse-proxy
    spec:
      serviceAccountName: envoy-reverse-proxy-sa
      containers:
      - name: envoy-reverse-proxy
        image: $REPO_URI:latest
        imagePullPolicy: Always
        ports:
          - containerPort: 80
EOF
kubectl -n cluster1-envoy-reverse-proxy-ns apply -f ${YAML_PATH}/envoy-reverse-proxy.yaml

echo "Adding Istio External Authorization Provider"
cat << EOF > ${YAML_PATH}/cluster1-auth-provider.yaml
---
apiVersion: v1
data:
  mesh: |-
    accessLogFile: /dev/stdout
    defaultConfig:
      discoveryAddress: istiod.istio-system.svc:15012
      proxyMetadata: {}
      tracing:
        zipkin:
          address: zipkin.istio-system:9411
    enablePrometheusMerge: true
    rootNamespace: istio-system
    trustDomain: cluster.local
    extensionProviders:
    - name: rev-proxy
      envoyExtAuthzHttp:
        service: envoy-reverse-proxy.cluster1-envoy-reverse-proxy-ns.svc.cluster.local
        port: "80"
        timeout: 1.5s
        includeHeadersInCheck: ["authorization", "cookie"]
        headersToUpstreamOnAllow: ["authorization", "path", "x-auth-request-user", "x-auth-request-email"]
        headersToDownstreamOnDeny: ["content-type", "set-cookie"]
EOF
kubectl -n istio-system patch configmap istio --patch "$(cat ${YAML_PATH}/cluster1-auth-provider.yaml)"
kubectl rollout restart deployment/istiod -n istio-system

echo "Configuring AuthorizationPolicy on Istio Ingress Gateway"
kubectl apply -f ${YAML_PATH}/cluster1-auth-policy.yaml
