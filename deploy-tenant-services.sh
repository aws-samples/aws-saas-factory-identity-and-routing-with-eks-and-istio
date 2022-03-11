#!/usr/bin/bash
. ~/.bash_profile

# Add oauth2-proxy Helm Repo
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests

echo "Deploying Tenant A services on EKS..."

echo "-> Deploying bookinfo service"
kubectl -n cluster1-tenanta-ns apply -f bookinfo.yaml

echo "-> Deploying VirtualService to expose bookinfo via Ingress Gateway"
cat << EOF > ${YAML_PATH}/bookinfo-ta-vs.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - tenanta.example.com
  gateways:
  - cluster1-gateway-ns/gateway
  http:
  - match:
    - uri:
        exact: /bookinfo
    rewrite:
        uri: /productpage
    route:
    - destination:
        host: productpage
        port:
          number: 9080
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        prefix: /api/v1/products
    - uri:
        prefix: /oauth2/callback
    route:
    - destination:
        host: productpage
        port:
          number: 9080
EOF
kubectl -n cluster1-tenanta-ns apply -f ${YAML_PATH}/bookinfo-ta-vs.yaml 

echo "Deploying OIDC Proxy for Tenant A"
helm install --namespace cluster1-tenanta-oidc-proxy-ns oauth2-proxy \
  oauth2-proxy/oauth2-proxy -f ${YAML_PATH}/oauth2-proxy-tenanta-values.yaml

echo "Deploying Tenant B services on EKS..."

echo "-> Deploying bookinfo service"
kubectl -n cluster1-tenantb-ns apply -f bookinfo.yaml

echo "-> Deploying VirtualService to expose bookinfo via Ingress Gateway"
cat << EOF > ${YAML_PATH}/bookinfo-tb-vs.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - tenantb.example.com
  gateways:
  - cluster1-gateway-ns/gateway
  http:
  - match:
    - uri:
        exact: /bookinfo
    rewrite:
        uri: /productpage
    route:
    - destination:
        host: productpage
        port:
          number: 9080
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        prefix: /api/v1/products
    - uri:
        prefix: /oauth2/callback
    route:
    - destination:
        host: productpage
        port:
          number: 9080
EOF
kubectl -n cluster1-tenantb-ns apply -f ${YAML_PATH}/bookinfo-tb-vs.yaml 

echo "Deploying OIDC Proxy for Tenant B"
helm install --namespace cluster1-tenantb-oidc-proxy-ns oauth2-proxy \
  oauth2-proxy/oauth2-proxy -f ${YAML_PATH}/oauth2-proxy-tenantb-values.yaml