#!/usr/bin/env bash

source /etc/os-release
OS_STRING="${ID}-${VERSION_ID}"

echo "Setup docker for ${OS_STRING}"

SETUP_SCRIPT_URL="https://raw.githubusercontent.com/pipiobjo/k8s-playground/main/windows-and-docker/${OS_STRING}.sh"
SETUP_SCRIPT="/tmp/dockerSetup.sh"
if ! curl -sf -L "${SETUP_SCRIPT_URL}" -o "${SETUP_SCRIPT}" --retry 3 --fail; then
  echo "Failed to download docker setup script from ${SETUP_SCRIPT_URL}"
  exit 1
fi
chmod +x "${SETUP_SCRIPT}"
"${SETUP_SCRIPT}"

