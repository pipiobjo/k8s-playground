#!/bin/bash

set -o errexit
#set -x


# CONSTANTS
SHOW_HELP=false
RESET_K8S=false
REMOVE_K8S=false
VERBOSE=false
SKIP_INFRASTRUCTURE=false

#### LOAD K8S DEFAULTS
EXEC_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR="$EXEC_DIR/k8s/scripts/"
source $SCRIPT_DIR/k8s-env.sh

function usage {
    echo "usage: localDev.sh"
    echo "  -r  | --restart        includes wiping out the current kind settings and starts with a blank setup"
    echo "  -d  | --delete         stops the kind cluster and removes it"
#    echo "  -s  | --skip-infra     skips infrastructure setup"
#    echo "  -v  | --verbose        running skaffold in verbose mode"
    exit 1
}

for i in "$@"; do
  case $i in
    -r|--reset-k8s)
      RESET_K8S=true
      shift
      ;;
    -rm | --remove)
      REMOVE_K8S=true
      ;;
    -v | --verbose)
      VERBOSE=true
      ;;
   -s|--skip-infra)
     SKIP_INFRASTRUCTURE=true
     shift
     ;;
#    -l=*|--lib=*)
#      LIBPATH="${i#*=}"
#      shift # past argument=value
#      ;;
    -h|--help)
      SHOW_HELP=true
      shift
      ;;
    *)
      # unknown option
      SHOW_HELP=true
      shift
      ;;
  esac
done


if $SHOW_HELP ; then
    usage
fi

if $REMOVE_K8S ; then
    $SCRIPT_DIR/K8skindCluster.sh delete
    exit
fi

if $RESET_K8S ; then
    $SCRIPT_DIR/K8skindCluster.sh delete
fi

if ! $SKIP_INFRASTRUCTURE ; then
  $SCRIPT_DIR/K8skindCluster.sh start
fi
