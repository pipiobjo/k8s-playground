#!/bin/bash
# https://stackoverflow.com/questions/37033055/how-can-i-use-the-docker-registry-api-v2-to-delete-an-image-from-a-private-regis
#set -x

EXEC_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR="$EXEC_DIR/k8s/scripts/"
source $SCRIPT_DIR/k8s-env.sh

REGISTRY_HOST="http://${DOCKER_REGISTRY_HOST}:${DOCKER_REGISTRY_PORT}"

function deleteImage(){
  REPO=$1
  TAG=$2
  DIGEST=$3
#  curl -X DELETE -I -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' http://localhost:5001/v2/dca-security/manifests/sha256:0c23c4729bb15e5172d707a620b45641e88f8823fbc148733267ec3621b82f8e
  curl -X DELETE -s -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $REGISTRY_HOST/v2/$REPO/manifests/$DIGEST
}


function checkTag(){
  REPO=$1
  TAG=$2

  DIGEST=$(curl -X HEAD -I -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "$REGISTRY_HOST/v2/$REPO/manifests/$TAG" | grep "Docker-Content-Digest" | cut -d' ' -f2 )

  if [ -z "$DIGEST" ]
  then
        echo "No Digest found for REPO=$REPO TAG=$TAG"
  else
#        echo "REPO=$REPO TAG=$TAG DIGEST=$DIGEST"
        DIGEST=$(echo $DIGEST | tr -d '\r')
        deleteImage $REPO $TAG $DIGEST
  fi

}

function checkRepo(){
  REPO=$1
  echo "repo $REPO list tags"
  curl -s "$REGISTRY_HOST/v2/$REPO/tags/list" | jq '(.tags[])?'
  TAGS=$(curl -s "$REGISTRY_HOST/v2/$REPO/tags/list" | jq -c -r '(.tags[])?') # ? prevents jq from failing if tags is null

  # shellcheck disable=SC2068
  for TAG in ${TAGS[@]}; do
      checkTag $REPO $TAG
  done
}

echo "available repos"
curl -s "$REGISTRY_HOST/v2/_catalog" | jq '.repositories'
REPOS=$(curl -s "$REGISTRY_HOST/v2/_catalog" | jq -c -r '.repositories[]')

# shellcheck disable=SC2068
for REPO in ${REPOS[@]}; do
    checkRepo $REPO
done

echo "execute garbage collection"
docker exec -d ${DOCKER_INTERNAL_REGISTRY_NAME} touch registry garbage-collect /etc/docker/registry/config.yml