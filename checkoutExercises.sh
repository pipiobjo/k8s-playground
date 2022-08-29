#!/bin/bash

set -o errexit # fail on error
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/"
CURRENT_DIR=pwd

EXERCISE_FOLDER=$SCRIPT_DIR/../exercises
mkdir -p $EXERCISE_FOLDER
cd $EXERCISE_FOLDER
git clone git@github.com:pipiobjo/k8s-playground-basics.git

PLAYGROUND_BASICS_DIR="$EXERCISE_FOLDER/k8s-playground-basics"
if [ -d "$PLAYGROUND_BASICS_DIR" ]; then
  echo "pulling new files ${PLAYGROUND_BASICS_DIR} ..."
  cd ${PLAYGROUND_BASICS_DIR}
  git pull
fi

# switch back to exercise folder to checkout the next repo
cd $EXERCISE_FOLDER



# switch back to user incoming dir
cd $CURRENT_DIR