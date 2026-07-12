#!/usr/bin/env bash

SHARED_BUILD_OPTION=${1:-shared}
OPENSSL_SOURCE_DIR=${2:-openssl}
OPENSSL_INSTALL_DIR=${3:-build/openssl}

source "$(pwd)/setup.sh" || exit 1

if [ ! -d "$ANDROID_SDK_ROOT" ] ; then
  echo "Error: directory \"$ANDROID_SDK_ROOT\" doesn't exist. Run ./fetch-sdk.sh first, or provide a valid path to Android SDK."
  exit 1
fi

if [ -e "$OPENSSL_INSTALL_DIR" ] ; then
  echo "Error: file or directory \"$OPENSSL_INSTALL_DIR\" already exists. Delete it manually to proceed."
  exit 1
fi

source ./td/example/android/check-environment.sh || exit 1

mkdir -p $OPENSSL_INSTALL_DIR || exit 1

ANDROID_SDK_ROOT="$(cd "$(dirname -- "$ANDROID_SDK_ROOT")" >/dev/null; pwd -P)/$(basename -- "$ANDROID_SDK_ROOT")"
OPENSSL_INSTALL_DIR="$(cd "$(dirname -- "$OPENSSL_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$OPENSSL_INSTALL_DIR")"
OPENSSL_SOURCE_DIR="$(cd "$(dirname -- "$OPENSSL_SOURCE_DIR")" >/dev/null; pwd -P)/$(basename -- "$OPENSSL_SOURCE_DIR")"

cd $(dirname $0)

pushd "$OPENSSL_SOURCE_DIR" > /dev/null

# Make sure it's clean build
make distclean > /dev/null 2>&1 || true

ANDROID_NDK_VERSION=$ANDROID_NDK_VERSION_PRIMARY
export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"  # for OpenSSL 3.*.*
export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT "                          # for OpenSSL 1.1.1
PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$HOST_ARCH/bin:$PATH"

if ! clang --help >/dev/null 2>&1 ; then
  echo "Error: failed to run clang from Android NDK."
  if [[ "$OS_NAME" == "linux" ]] ; then
    echo "Prebuilt Android NDK binaries are linked against glibc, so glibc must be installed."
  fi
  exit 1
fi

ANDROID_API32=16
ANDROID_API64=21
if [[ ${ANDROID_NDK_VERSION%%.*} -ge 24 ]] ; then
  ANDROID_API32=19
fi
if [[ ${ANDROID_NDK_VERSION%%.*} -ge 26 ]] ; then
  ANDROID_API32=21
fi

for ABI in x86 armeabi-v7a x86_64 arm64-v8a ; do
  rm -f libcryptox.so libsslx.so libssl.so libsslx.so

  PARAMS="no-tests no-docs no-apps no-legacy no-engine"

  if [[ $ABI == "x86" ]] ; then
    ./Configure android-x86 ${SHARED_BUILD_OPTION} ${PARAMS} -U__ANDROID_API__ -D__ANDROID_API__=$ANDROID_API32 || exit 1
  elif [[ $ABI == "x86_64" ]] ; then
    LDFLAGS=-Wl,-z,max-page-size=16384 ./Configure android-x86_64 ${SHARED_BUILD_OPTION} ${PARAMS} -U__ANDROID_API__ -D__ANDROID_API__=$ANDROID_API64 || exit 1
  elif [[ $ABI == "armeabi-v7a" ]] ; then
    ./Configure android-arm ${SHARED_BUILD_OPTION} ${PARAMS} -U__ANDROID_API__ -D__ANDROID_API__=$ANDROID_API32 -D__ARM_MAX_ARCH__=8 || exit 1
  elif [[ $ABI == "arm64-v8a" ]] ; then
    LDFLAGS=-Wl,-z,max-page-size=16384 ./Configure android-arm64 ${SHARED_BUILD_OPTION} ${PARAMS} -U__ANDROID_API__ -D__ANDROID_API__=$ANDROID_API64 || exit 1
  fi

  sed -i.bak \
  -e 's/-O3/-O3 -ffunction-sections -fdata-sections/g' \
  -e 's/libcrypto\.so/libcryptox.so/g' \
  -e 's/libcrypto\.a/libcryptox.a/g' \
  -e 's|-lcrypto |-lcryptox |g' \
  -e 's|-lcrypto$|-lcryptox|g' \
  -e 's/libssl\.so/libsslx.so/g' \
  -e 's/libssl\.a/libsslx.a/g' \
  Makefile || exit 1

  make depend -s || exit 1
  make -j4 -s || exit 1

  (test -f libcryptox.so && test -f libsslx.so) || exit 1

  echo "Creating symlinks..."

  ln -sf libcryptox.so libcrypto.so
  ln -sf libsslx.so libssl.so

  echo "Copying to $OPENSSL_INSTALL_DIR/$ABI"
  mkdir -p "$OPENSSL_INSTALL_DIR/$ABI/lib" || exit 1
  (cp -a libcryptox.so libcrypto.so libsslx.so libssl.so "$OPENSSL_INSTALL_DIR/$ABI/lib/.") || exit 1
  cp -r include "$OPENSSL_INSTALL_DIR/$ABI/." || exit 1

  echo "Built OpenSSL for $ABI with NDK $ANDROID_NDK_VERSION: $OPENSSL_INSTALL_DIR/$ABI"

  make distclean || exit 1
done

OPENSSL_COMMIT="$(git rev-parse HEAD)"
echo "$OPENSSL_COMMIT" > "$OPENSSL_INSTALL_DIR/version.txt"

popd > /dev/null

echo "Build OpenSSL: $OPENSSL_INSTALL_DIR, commit: $OPENSSL_COMMIT"
