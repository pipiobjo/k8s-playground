#!/bin/bash

set -o errexit
#set -x

#### LOAD CONSTANTS
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/k8s-env.sh

### INTERNAL STATE VARS
KIND_STATE_UP="UP"
KIND_STATE_DOWN="DOWN"
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

_installIngress(){

  echo "provide ingress"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

  echo "wait for ingress to be ready"
  sleep 15s
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=190s

}



_startSamplePod(){
  docker pull gcr.io/google-samples/hello-app:1.0
  docker tag gcr.io/google-samples/hello-app:1.0 localhost:${DOCKER_REGISTRY_PORT}/hello-app:1.0
  docker push localhost:${DOCKER_REGISTRY_PORT}/hello-app:1.0
  kubectl create deployment hello-server --image=localhost:${DOCKER_REGISTRY_PORT}/hello-app:1.0
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
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP


containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${DOCKER_REGISTRY_PORT}"]
    endpoint = ["http://${DOCKER_INTERNAL_REGISTRY_NAME}:${DOCKER_REGISTRY_PORT}"]
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
    host: "http://${DOCKER_INTERNAL_REGISTRY_NAME}:${DOCKER_REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

_initDockerRegistry
_installMetricServer
_installIngress
# _startSamplePod
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