#!/usr/bin/bash
. ~/.bash_profile

echo "Installing Istio with Ingress Gateway (NLB)"
export ISTIO_VERSION="1.11.8"

curl --no-progress-meter -L https://istio.io/downloadIstio | sh -
cd istio-${ISTIO_VERSION}
bin/istioctl version
sudo cp -v bin/istioctl /usr/local/bin/

istioctl install -y \
  --set profile=demo \
  --set components.egressGateways[0].name=istio-egressgateway \
  --set components.egressGateways[0].enabled=false \
  --set "values.gateways.istio-ingressgateway.serviceAnnotations.service\.beta\.kubernetes\.io/aws-load-balancer-type"='nlb' \
  --set "values.gateways.istio-ingressgateway.serviceAnnotations.service\.beta\.kubernetes\.io/aws-load-balancer-proxy-protocol"='*'

cd ..

export LB_NAME=$(kubectl -n istio-system \
         get svc istio-ingressgateway \
         -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}'| \
         awk -F- '{print $1}')

kubectl -n istio-system get svc
kubectl -n istio-system get pods

STATUS=$(aws elbv2 describe-load-balancers --name ${LB_NAME} \
  --query 'LoadBalancers[0].State.Code')

echo "Status of Load Balancer ${LB_NAME}: $STATUS"