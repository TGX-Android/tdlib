#!/bin/bash
set -e

MODE=${1:---full}

# Assumes we are in tgx/tdlib/source
pushd ../.. > /dev/null || exit 1

if [[ "$MODE" == "--full" ]] ; then
  source "$(pwd)/scripts/set-env.sh"
elif [[ "$MODE" == "--light" ]] ; then
  CMAKE_VERSION=$(scripts/./read-property.sh version.properties version.cmake)
  ANDROID_NDK_VERSION_PRIMARY=$(scripts/./read-property.sh version.properties version.ndk_primary)
  ANDROID_NDK_VERSION_LEGACY=$(scripts/./read-property.sh version.properties version.ndk_legacy)
  export CMAKE_VERSION
  export ANDROID_NDK_VERSION_PRIMARY
  export ANDROID_NDK_VERSION_LEGACY
else
  echo "Usage: setup.sh [--full|--light], provided: $MODE"
fi

popd > /dev/null