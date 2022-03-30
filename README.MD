# Local Development Setup

## Requirements

* Install kind cli from <https://github.com/kubernetes-sigs/kind>

## K8s

Setup K8s Cluster

* Setup K8s and update kubectl config
* Install Ingress
* Install Metriks Server

```bash

./localK8s.sh

```

### Check if k8s is setup correct

```
kubectl config current-context    
kind-myscope


kubectl -n kube-system get pods 
NAME                                                READY   STATUS    RESTARTS   AGE
coredns-64897985d-g42h9                             1/1     Running   0          14m
coredns-64897985d-q8tn5                             1/1     Running   0          14m
etcd-myscope-control-plane                      1/1     Running   0          15m
kindnet-kb8xw                                       1/1     Running   0          14m
kube-apiserver-myscope-control-plane            1/1     Running   0          15m
kube-controller-manager-myscope-control-plane   1/1     Running   0          15m
kube-proxy-dn4cs                                    1/1     Running   0          14m
kube-scheduler-myscope-control-plane            1/1     Running   0          15m
metrics-server-746bcc574b-nnpcw                     1/1     Running   0          14m



kubectl top nodes             
NAME                        CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
myscope-control-plane   334m         4%     790Mi           2%        


```

## Remove / uninstall k8s

* Removes the whole k8s cluster
* Stops all containers
* Removes the created container registry

```bash
./localDev.sh -d
```

If you want to remove everything, like docker network or stored images call, consider calling:

```bash
docker system prune
```

## Activate kubectl autocompletion

check according to your terminal <https://kubernetes.io/docs/tasks/tools/included/>

Activate for zsh

```bash
source <(kubectl completion zsh)
```

Sample Usage

```bash
kubectl -n ofc get po [Press 'TAB']
```

## Kind Troubleshooting

Query Container Reqistry for all images

```bash
curl -s "http://localhost:5000/v2/_catalog"  | jq
{
  "repositories": [
    "blueprint-greeting"
  ]
}
```

Query tags for a specific image

```bash
curl -s "http://localhost>:5000/v2/$MY_IMAGE_NAME/tags/list" | jq
```

Query image information for a specific image and tag

```bash
curl -s "http://localhost>:5000/v2/$MY_IMAGE_NAME/manifests/$TAG_NAME" | jq
```
