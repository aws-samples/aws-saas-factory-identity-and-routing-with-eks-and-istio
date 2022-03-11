#!/usr/bin/bash
. ~/.bash_profile

echo "Deploying Tenant C services on EKS..."

echo "-> Deploying bookinfo service"
kubectl -n cluster1-tenantc-ns apply -f bookinfo.yaml

echo "-> Deploying VirtualService to expose bookinfo via Ingress Gateway"
cat << EOF > ${YAML_PATH}/bookinfo-tc-vs.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - tenantc.example.com
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
kubectl -n cluster1-tenantc-ns apply -f ${YAML_PATH}/bookinfo-tc-vs.yaml 

echo "Deploying OIDC Proxy for Tenant C"
helm install --namespace cluster1-tenantc-oidc-proxy-ns oauth2-proxy \
  oauth2-proxy/oauth2-proxy -f ${YAML_PATH}/oauth2-proxy-tenantc-values.yaml
