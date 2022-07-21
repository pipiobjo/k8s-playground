#!/bin/bash

DOCKER_INTERNAL_REGISTRY_NAME='k8s-playground-kind-registry'
DOCKER_REGISTRY_PORT='5003'
DOCKER_REGISTRY_HOST='localhost'
KIND_CLUSTER_NAME='k8s-playground' # only lower case allowed and has to be a valid RFC-1123 DNS subdomain

# external ports
K8S_TRAEFIK_DASHBOARD_PORT=40001
K8S_HTTP_PORT=48080
K8S_HTTPS_PORT=48443



##########################################
############## INTERNAL ##################
##########################################


# internal ports - dont change if you dont know what you are doing
KIND_NODE_PORT_TRAEFIK=30009
KIND_NODE_PORT_HTTP=30008
KIND_NODE_PORT_HTTPS=30043

