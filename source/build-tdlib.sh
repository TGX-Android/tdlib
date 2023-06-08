#!/usr/bin/env bash

TDLIB_SOURCE_DIR=${1:-td}
TDLIB_INSTALL_DIR=${2:-build/td}
OPENSSL_INSTALL_DIR=${3:-build/openssl}
ANDROID_STL=${4:-c++_shared}

source "$(pwd)/setup.sh" --light

if [ "$ANDROID_STL" != "c++_static" ] && [ "$ANDROID_STL" != "c++_shared" ] ; then
  echo 'Error: ANDROID_STL must be either "c++_static" or "c++_shared".'
  exit 1
fi

if [ "$CMAKE_VERSION" != "3.22.1" ] ; then
  echo 'Error: CMAKE_VERSION must be 3.22.1'
  exit 1
fi

if [ ! -d "$JAVA_HOME" ] ; then
  echo "Error: directory \"$JAVA_HOME\" doesn't exist. Set a valid path via JAVA_HOME."
  exit 1
fi

if [ ! -d "$ANDROID_SDK_ROOT" ] ; then
  echo "Error: directory \"$ANDROID_SDK_ROOT\" doesn't exist. Set a valid path via ANDROID_SDK_ROOT."
  exit 1
fi

if [ ! -d "$OPENSSL_INSTALL_DIR" ] ; then
  echo "Error: directory \"$OPENSSL_INSTALL_DIR\" doesn't exists. Run ./build-openssl.sh first."
  exit 1
fi

if [ -e "$TDLIB_INSTALL_DIR" ] ; then
  echo "Error: file or directory \"$TDLIB_INSTALL_DIR\" already exists. Delete it manually to proceed."
  exit 1
fi

ANDROID_SDK_ROOT="$(cd "$(dirname -- "$ANDROID_SDK_ROOT")" >/dev/null; pwd -P)/$(basename -- "$ANDROID_SDK_ROOT")"
ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"
TDLIB_SOURCE_DIR="$(cd "$(dirname -- "$TDLIB_SOURCE_DIR")" >/dev/null; pwd -P)/$(basename -- "$TDLIB_SOURCE_DIR")"
TDLIB_INSTALL_DIR="$(cd "$(dirname -- "$TDLIB_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$TDLIB_INSTALL_DIR")"
OPENSSL_INSTALL_DIR="$(cd "$(dirname -- "$OPENSSL_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$OPENSSL_INSTALL_DIR")"

pushd "$TDLIB_SOURCE_DIR/example/android" > /dev/null || exit 1
rm -rf build-native build-arm64-v8a build-armeabi-v7a build-x86_64 build-x86 tdlib
sed -i.bak 's/cmake -DCMAKE_TOOLCHAIN_FILE/cmake -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--gc-sections,--icf=safe" -DCMAKE_TOOLCHAIN_FILE/g' build-tdlib.sh || exit 1
./build-tdlib.sh "$ANDROID_SDK_ROOT" "$NDK_VERSION" "$OPENSSL_INSTALL_DIR" "$ANDROID_STL" || exit 1
popd > /dev/null

pushd "$TDLIB_SOURCE_DIR" > /dev/null || exit 1
TDLIB_COMMIT="$(git rev-parse HEAD)"
popd > /dev/null

mkdir -p "$TDLIB_INSTALL_DIR"
mv "$TDLIB_SOURCE_DIR/example/android/tdlib" "$TDLIB_INSTALL_DIR/tdlib" || exit 1
echo "$TDLIB_COMMIT" > "$TDLIB_INSTALL_DIR/version.txt"

echo "Built TDLib: $TDLIB_INSTALL_DIR, commit: $TDLIB_COMMIT"
