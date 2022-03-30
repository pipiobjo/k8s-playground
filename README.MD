# Local Development Setup

## Requirements

* Install kind cli from https://github.com/kubernetes-sigs/kind

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

./localDev.sh -rm

```


## Activate kubectl autocompletion

check according to your terminal https://kubernetes.io/docs/tasks/tools/included/

. Sample
```bash

kubectl -n ofc get po [Press 'TAB']

```



## Kind Troubleshooting


Query Container Reqistry for all images

```bash
curl -s http://localhost:5005/v2/_catalog | jq
{
"repositories": []
}
```
