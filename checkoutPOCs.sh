  #!/bin/bash

set -o errexit # fail on error
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/"
CURRENT_DIR=$(pwd)

POC_FOLDER=$SCRIPT_DIR/../pocs
mkdir -p $POC_FOLDER
cd $POC_FOLDER
git clone git@github.com:pipiobjo/compare-programming-languages.git

PLAYGROUND_BASICS_DIR="$POC_FOLDER/compare-programming-languages"
if [ -d "$PLAYGROUND_BASICS_DIR" ]; then
  echo "pulling new files ${PLAYGROUND_BASICS_DIR} ..."
  cd ${PLAYGROUND_BASICS_DIR}
  git pull
fi

# switch back to exercise folder to checkout the next repo
cd $POC_FOLDER



# switch back to user incoming dir
cd $CURRENT_DIR
