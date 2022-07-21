#!/bin/bash

set -o errexit
#set -x

#### LOAD CONSTANTS
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/k8s-env.sh
source $SCRIPT_DIR/define-colors.sh

### INTERNAL STATE VARS
KIND_STATE_UP="UP"
KIND_STATE_DOWN="DOWN"
SAMPLE_APP_ACTIVATED=false
###

_isKindRunning() {
  # check if cluster is running
  # should contain KIND_CLUSTER_NAME if it is running
  if kind get clusters | grep -q $KIND_CLUSTER_NAME; then
    echo KIND_STATE_UP
  else
    echo KIND_STATE_DOWN
  fi

}


  ###
  ### installing metric server
  ###
_installMetricServer(){
echo "install metric server"

# helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
# helm upgrade --install metrics-server metrics-server/metrics-server
# ensure the secure-port matches the container port
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/metrics-server-helm-chart-3.8.2/components.yaml
PATCH=$(cat <<EOF
spec:
  template:
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --kubelet-preferred-address-types=InternalIP
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls
        - --secure-port=4443
        name: metrics-server
EOF
)
kubectl patch deployment metrics-server -n kube-system --patch "$PATCH"

echo "waiting for metrics deployment ..."
kubectl wait --namespace kube-system \
 --for=condition=available deployment \
 --selector=k8s-app=metrics-server \
 --timeout=190s


}

_installNginxIngress(){
  INGRESS_IMPL="nginx"
  echo "provide ingress"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

  echo "wait for ingress to be ready"
  sleep 15s
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=190s

}

_installTraefik(){
  INGRESS_IMPL="traefik"
#  source $SCRIPT_DIR/k8s/scripts/define-colors
  # https://doc.traefik.io/traefik/getting-started/install-traefik/#use-the-helm-chart
  # https://github.com/traefik/traefik-helm-chart
  TRAEFIK_K8S_NAMESPACE="traefik"

  echo -e "${GREEN} install traefik ${NO_COLOR}"
  echo "create traefik namespace"
  kubectl create namespace $TRAEFIK_K8S_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

  HELM_VALUES=$SCRIPT_DIR/../traefik/helm/values.yaml
  echo "install helm chart"
  echo "-referenced values file $HELM_VALUES"

  helm repo add traefik https://helm.traefik.io/traefik
  helm repo update
  helm install traefik traefik/traefik \
    -n $TRAEFIK_K8S_NAMESPACE \
    -f $HELM_VALUES \
    --set ports.traefik.nodePort=$KIND_NODE_PORT_TRAEFIK \
    --set ports.web.nodePort=$KIND_NODE_PORT_HTTP \
    --set ports.websecure.nodePort=$KIND_NODE_PORT_HTTPS \


  kubectl rollout status deployment "traefik" -n $TRAEFIK_K8S_NAMESPACE --watch --timeout=15m

}



_startSamplePod(){
  SAMPLE_APP_ACTIVATED=true
  # https://cloud.google.com/kubernetes-engine/docs/samples/container-hello-app
  # https://github.com/GoogleCloudPlatform/kubernetes-engine-samples/tree/f044a416bd3c6a0dc2c319fe5cc4def80fc4e9a1/hello-app
  echo "install sample app"
  docker pull gcr.io/google-samples/hello-app:1.0
  docker tag gcr.io/google-samples/hello-app:1.0 localhost:${DOCKER_REGISTRY_PORT}/hello-app:1.0
  docker push localhost:${DOCKER_REGISTRY_PORT}/hello-app:1.0
#  kubectl create deployment hello-server --image=localhost:${DOCKER_REGISTRY_PORT}/hello-app:1.0
kubectl create namespace demo

  cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  namespace: demo
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: localhost:${DOCKER_REGISTRY_PORT}/hello-app:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 200m
EOF



  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: helloweb-backend
  namespace: demo
  labels:
    app: hello
spec:
  selector:
    app: hello
    tier: web
  ports:
  - port: 8080
    targetPort: 8080
EOF

if [[ "$INGRESS_IMPL" == "nginx" ]]; then
    echo "deploy nginx ingress config"
    cat <<EOF | kubectl apply -f -
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: helloweb
        namespace: demo
        annotations:
            nginx.ingress.kubernetes.io/rewrite-target: /$2
        labels:
          app: hello
      spec:
        ingressClassName: nginx
        rules:
          - http:
              paths:
                - path: /demo(/|$)(.*)
                  pathType: Prefix
                  backend:
                    service:
                      name: helloweb-backend
                      port:
                        number: 8080
EOF
fi



if [[ "$INGRESS_IMPL" == "traefik" ]]; then
  echo "deploy traefik ingress config"
  cat <<EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: strip-prefix
  namespace: demo # Namespace defined
spec:
  stripPrefix:
    prefixes:
      - /demo/
    forceSlash: true
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: helloweb
  namespace: demo
  annotations:
      traefik.ingress.kubernetes.io/router.middlewares: demo-strip-prefix@kubernetescrd
  labels:
    app: hello
spec:
  rules:
    - http:
        paths:
          - path: /demo/
            pathType: Prefix
            backend:
              service:
                name: helloweb-backend
                port:
                  number: 8080
EOF
fi


kubectl -n demo rollout status deployment helloweb --watch --timeout=5m


}


_initDockerRegistry(){
  running="$(docker inspect -f '{{.State.Running}}' "${DOCKER_INTERNAL_REGISTRY_NAME}" 2>/dev/null || true)"
  if [ "${running}" != 'true' ]; then
    echo "kind docker registry is not running ... starting"
    docker run \
      -d \
      --publish "${DOCKER_REGISTRY_PORT}:5000" \
      --restart=always \
      --name "${DOCKER_INTERNAL_REGISTRY_NAME}" \
      --net=kind \
      -e REGISTRY_STORAGE_DELETE_ENABLED=true \
      registry:2

      # connect the registry to the cluster network (the network may already be connected)
      #echo " 🔗 Connect registry container to docker network 'kind'"
      #docker network connect "kind" "${DOCKER_INTERNAL_REGISTRY_NAME}" || true
  fi


}



_createKindCluster() {



#DOCKER_REGISTRY_IP="$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' "${DOCKER_INTERNAL_REGISTRY_NAME}")"
#echo "Registry IP: ${DOCKER_REGISTRY_IP}"

# create a cluster with the local registry enabled in containerd
# ingress setup https://kind.sigs.k8s.io/docs/user/ingress/
# local registry https://kind.sigs.k8s.io/docs/user/local-registry/
  # http - containerPort: 80 ingress
  # https- containerPort: 443 ingress
cat <<EOF | kind create cluster --name $KIND_CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: $KIND_NODE_PORT_HTTP
    hostPort: $K8S_HTTP_PORT
    protocol: TCP
  - containerPort: $KIND_NODE_PORT_HTTPS
    hostPort: $K8S_HTTPS_PORT
    protocol: TCP
  - containerPort: $KIND_NODE_PORT_TRAEFIK
    hostPort: $K8S_TRAEFIK_DASHBOARD_PORT
    protocol: TCP


containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${DOCKER_REGISTRY_PORT}"]
    endpoint = ["http://${DOCKER_INTERNAL_REGISTRY_NAME}:5000"]
EOF



# configure local docker registry https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${DOCKER_REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

_initDockerRegistry
_installMetricServer
_installNginxIngress
#_installTraefik
_startSamplePod

sleep 5s

if [[ "$INGRESS_IMPL" == "traefik" ]]; then
  echo -e "${GREEN} curl http://localhost:$K8S_TRAEFIK_DASHBOARD_PORT/dashboard/ ${NO_COLOR}"
  curl http://localhost:$K8S_TRAEFIK_DASHBOARD_PORT/dashboard/
  echo ""
fi

# sleep 5s
if [ "$SAMPLE_APP_ACTIVATED" = true ] ; then
  echo -e "${GREEN} curl http://localhost:$K8S_HTTP_PORT/demo/hello ${NO_COLOR}"
  curl http://localhost:$K8S_HTTP_PORT/demo/hello

  echo -e "${GREEN} curl -k https://localhost:$K8S_HTTPS_PORT/demo/hello ${NO_COLOR}"
  curl -k https://localhost:$K8S_HTTPS_PORT/demo/hello
fi
}


start() {
  KIND_IS_RUNNING=$(_isKindRunning)
  if echo "$KIND_IS_RUNNING" | grep -q $KIND_STATE_UP; then
    echo "Kind is already running"
  else
    echo "Kind is not running ... starting it"
    _createKindCluster
  fi

}


stop() {
    # stop registry
    echo "stopping kind cluster"
    docker stop "${DOCKER_INTERNAL_REGISTRY_NAME}"
}

delete(){

  echo "delete kind cluster"
  kind delete cluster --name $KIND_CLUSTER_NAME

  # delete container registry
  echo "delete container registry $DOCKER_INTERNAL_REGISTRY_NAME"
  docker rm $DOCKER_INTERNAL_REGISTRY_NAME
#  docker rmi registry:2


}


status(){
  running="$(docker inspect -f '{{.State.Running}}' "${DOCKER_INTERNAL_REGISTRY_NAME}" 2>/dev/null || true)"
  echo "container registry \"$DOCKER_INTERNAL_REGISTRY_NAME\" isRunning: $running"

  KIND_IS_RUNNING=$(_isKindRunning)

  if echo "$KIND_IS_RUNNING" | grep -q $KIND_STATE_UP; then
    echo "k8s: kind is running"
    kubectl cluster-info --context kind-$KIND_CLUSTER_NAME
    kubectl get pods -A
  else
    echo "k8s: kind is down"
  fi


}

case "$1" in
    start)
       start
       ;;
    stop)
       stop
       ;;
    restart)
       stop
       start
       ;;
    delete)
       stop
       delete
       ;;
    status)
       # code to check status of app comes here
       # example: status program_name
       status
       ;;
    *)
       echo "Usage: $0 {start|stop|status|restart|delete}"
esac