#!/bin/bash
set -e

MODE=${1:---full}

# Assumes we are in tgx/tdlib/source
pushd ../.. > /dev/null || exit 1

if [[ "$MODE" == "--full" ]] ; then
  source "$(pwd)/scripts/set-env.sh"
elif [[ "$MODE" == "--light" ]] ; then
  ANDROID_NDK_VERSION=$(scripts/./read-property.sh version.properties version.ndk)
  CMAKE_VERSION=$(scripts/./read-property.sh version.properties version.cmake)
  export ANDROID_NDK_VERSION
  export CMAKE_VERSION
else
  echo "Usage: setup.sh [--full|--light], provided: $MODE"
fi

popd > /dev/null