package tpl

const LocalRegistryConfigurationTpl string = `
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting{{.ClusterName}}
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "http://{{.ContainerRegistryName}}:{{.ContainerRegistryPort}}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
`

const KindClusterConfigTpl string = `
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster

nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: {{.KubernetsHttpPort}}
    hostPort: 80
    protocol: TCP
  - containerPort: {{.KubernetsHttpsPort}}
    hostPort: 443
    protocol: TCP


containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:{{.ContainerRegistryPort}}"]
    endpoint = ["http://{{.ContainerRegistryName}}:{{.ContainerRegistryPort}}"]
`

const MetrikServerPatchTpl string = `
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
`
